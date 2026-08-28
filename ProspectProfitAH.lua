ProspectProfit = ProspectProfit or {}
local PP = ProspectProfit
local AH = {}
PP.AH = AH

local PAGE_SIZE = 50
local READY_POLL = 0.05
local STACK_SIZE = 20

local function After(delay, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, fn)
    return
  end
  local f = CreateFrame("Frame")
  local t = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    if t >= delay then
      self:SetScript("OnUpdate", nil)
      fn()
    end
  end)
end

local function FrameVisible(frame)
  return frame and (frame.IsVisible and frame:IsVisible() or frame:IsShown()) and true or false
end

local function IsAHShown()
  if AH.isOpen then
    return true
  end
  if FrameVisible(AuctionFrame) then
    return true
  end
  if FrameVisible(AuctionFrameBrowse) or FrameVisible(AuctionFrameBid) or FrameVisible(AuctionFrameAuctions) then
    return true
  end
  if FrameVisible(_G.AuctionHouseFrame) then
    return true
  end
  return false
end

function AH:IsOpen()
  return IsAHShown()
end

function AH:HookAuctionFrame()
  if not AuctionFrame then
    return
  end
  if PP.UI then
    PP.UI:InstallTab()
  end
  if self.hooked then
    return
  end
  self.hooked = true
  AuctionFrame:HookScript("OnShow", function()
    AH:OnShown()
  end)
  AuctionFrame:HookScript("OnHide", function()
    AH:OnClosed()
  end)
  if AuctionFrame:IsShown() then
    self.isOpen = true
  end
end

function AH:IsBusy()
  return self.scanning and true or false
end

-- Prices are ALWAYS the instant-buy (buyout) amount. Bid-only rows are ignored.
-- Classic 2.5 / Anniversary: 7=levelColHeader (string), 8=minBid, 9=minIncrement, 10=buyout, 17=itemId
-- Original TBC:             7=minBid (number), 8=minIncrement, 9=buyout
local function ReadRow(index)
  local name, _, count, _, _, _, v7, v8, v9, v10, _, _, _, _, _, _, v17 =
    GetAuctionItemInfo("list", index)
  count = count or 1
  local buyout
  if type(v7) == "string" or type(v17) == "number" then
    buyout = v10
  else
    buyout = v9
  end
  buyout = tonumber(buyout) or 0
  local itemId = v17
  if type(itemId) ~= "number" then
    local link = GetAuctionItemLink("list", index)
    if link then
      itemId = tonumber(link:match("item:(%d+)"))
    end
  end
  return name, count, buyout, itemId
end

local function InstantBuy(index, expectedBuyout)
  local _, count, buyout, itemId = ReadRow(index)
  if not buyout or buyout <= 0 then
    return false, "Listing has no instant-buy price"
  end
  if expectedBuyout and buyout > expectedBuyout then
    return false, "Instant-buy price changed"
  end
  if GetMoney() < buyout then
    return false, "Not enough gold"
  end
  PlaceAuctionBid("list", index, buyout)
  return true, nil, { index = index, buyout = buyout, count = count, itemId = itemId }
end

local function SendQuery(name, page)
  QueryAuctionItems(name, nil, nil, page, nil, nil, false, true)
end

function AH.MinPositiveUnit(current, buyout, count)
  buyout = tonumber(buyout) or 0
  count = tonumber(count) or 0
  if buyout <= 0 or count <= 0 then
    return current
  end
  local unit = buyout / count
  if not current or unit < current then
    return unit
  end
  return current
end

function AH.ChooseCheapestBuyout(current, candidate, be1)
  if not candidate or candidate.count ~= STACK_SIZE then
    return current
  end
  if not PP.Economy.IsListingProfitable(candidate.buyout, candidate.count, be1) then
    return current
  end
  if not current or candidate.buyout < current.buyout then
    return candidate
  end
  return current
end

function AH.HasNextPage(page, batch, total)
  page = tonumber(page) or 0
  batch = tonumber(batch) or 0
  total = tonumber(total) or 0
  return total > 0 and ((page * PAGE_SIZE) + batch) < total
end

function AH:ResetJob()
  self.scanning = false
  self.expecting = false
  self.mode = nil
  self.ore = nil
  self.queue = nil
  self.qi = nil
  self.page = nil
  self.results = nil
  self.onComplete = nil
  self.commit = nil
  self.cachedGems = nil
  self.liveGems = nil
  self.generation = (self.generation or 0) + 1
end

function AH:Abort(message)
  local cb = self.onComplete
  local mode = self.mode
  self:ResetJob()
  if PP.UI then
    PP.UI:SetStatus(message or "Scan cancelled")
    PP.UI:Refresh()
  end
  if cb and (mode == "buyout" or mode == "commit") then
    cb(nil, message or "Scan cancelled")
  end
end

function AH:OnClosed()
  self.isOpen = false
  if self.scanning then
    self:Abort("Auction House closed")
  elseif PP.UI then
    PP.UI:Refresh()
  end
end

function AH:OnShown()
  self.isOpen = true
  self:HookAuctionFrame()
  if PP.UI then
    PP.UI:InstallTab()
    PP.UI:PlaceTab()
    if PP.UI:IsShown() then
      PP.UI.stickyStatus = nil
      PP.UI:Refresh()
    end
  end
end

function AH:CollectPage(itemId)
  local batch = GetNumAuctionItems("list")
  local r = self.results
  r.seen = r.seen or {}
  r.gems = r.gems or {}
  for i = 1, batch do
    local _, count, buyout, rowId = ReadRow(i)
    if rowId == itemId and buyout > 0 and count > 0 then
      if itemId == self.ore.id then
        r.oreMin = AH.MinPositiveUnit(r.oreMin, buyout, count)
        if count == STACK_SIZE and (not r.oreStack20 or buyout < r.oreStack20) then
          r.oreStack20 = buyout
        end
        if self.mode == "buyout" then
          local candidate = {
            page = self.page,
            index = i,
            buyout = buyout,
            count = count,
            itemId = itemId,
            marketScan = r.snapshotLastScan,
          }
          r.best = AH.ChooseCheapestBuyout(r.best, candidate, r.be1)
        end
        if self.mode == "commit" and self.commit and not r.commitHit then
          local want = self.commit
          if buyout <= want.buyout and count == want.count and itemId == want.itemId then
            r.commitHit = { index = i, buyout = buyout, count = count, itemId = itemId }
          end
        end
      else
        r.gems[itemId] = AH.MinPositiveUnit(r.gems[itemId], buyout, count)
      end
    end
  end
end

function AH:IsGemQuery()
  return self.mode == "scan" and self.ore and self.queue and self.queue[self.qi] and self.queue[self.qi] ~= self.ore.id
end

function AH:StatusText()
  if not self.scanning or not self.queue then
    return nil
  end
  local item = self.queue[self.qi]
  local name = item and PP.Data.GetName(item) or "?"
  if self.mode == "buyout" then
    return string.format("Finding stack of %d…", STACK_SIZE)
  end
  if self.mode == "commit" then
    return "Placing buyout…"
  end
  local cached = self.cachedGems or 0
  if item == (self.ore and self.ore.id) then
    local extra = cached > 0 and string.format(" · %d gems cached", cached) or ""
    return string.format("%s · page %d%s", name, (self.page or 0) + 1, extra)
  end
  local live = self.liveGems or 0
  local idx = self.qi - 1
  if live > 0 then
    return string.format("%s · gem %d/%d", name, idx, live)
  end
  return string.format("Scanning %d/%d · %s", self.qi, #self.queue, name)
end

function AH:WhenReady(fn)
  local gen = self.generation
  local function tick()
    if self.generation ~= gen or not self.scanning then
      return
    end
    if CanSendAuctionQuery() then
      fn()
      return
    end
    After(READY_POLL, tick)
  end
  tick()
end

function AH:Advance()
  self.qi = (self.qi or 1) + 1
  self.page = 0
  if not self.queue or self.qi > #self.queue then
    self:Finish()
    return
  end
  self:QueryCurrent()
end

function AH:QueryCurrent()
  if not self.scanning then
    return
  end
  if not IsAHShown() then
    self:Abort("Auction House closed")
    return
  end
  local itemId = self.queue[self.qi]
  if not itemId then
    self:Finish()
    return
  end
  local name = PP.Data.GetName(itemId)
  if not name then
    GetItemInfo(itemId)
    local gen = self.generation
    After(0.25, function()
      if self.generation == gen then
        if PP.Data.GetName(itemId) then
          self:QueryCurrent()
        else
          self:Advance()
        end
      end
    end)
    return
  end

  self:WhenReady(function()
    self.expecting = true
    if PP.UI then
      PP.UI:SetStatus(self:StatusText())
    end
    SendQuery(name, self.page)
  end)
end

function AH:FinishGem(itemId)
  if self.results then
    PP.DB:SaveGem(itemId, (self.results.gems and self.results.gems[itemId]) or 0)
  end
  self:Advance()
end

function AH:ProcessPage(itemId)
  self:CollectPage(itemId)
  if self.mode == "commit" then
    if self.results and self.results.commitHit then
      self:Finish()
      return
    end
    -- Keep paging until a matching 20-stack appears, then stop.
    local batch, total = GetNumAuctionItems("list")
    if AH.HasNextPage(self.page, batch, total) then
      self.page = self.page + 1
      self:QueryCurrent()
      return
    end
    self:Finish()
    return
  end

  if self.mode == "buyout" then
    local batch, total = GetNumAuctionItems("list")
    if AH.HasNextPage(self.page, batch, total) then
      self.page = self.page + 1
      self:QueryCurrent()
      return
    end
    self:Finish()
    return
  end

  if self:IsGemQuery() then
    local batch, total = GetNumAuctionItems("list")
    if AH.HasNextPage(self.page, batch, total) then
      self.page = self.page + 1
      self:QueryCurrent()
      return
    end
    self:FinishGem(itemId)
    return
  end

  local batch, total = GetNumAuctionItems("list")
  if AH.HasNextPage(self.page, batch, total) then
    self.page = self.page + 1
    self:QueryCurrent()
    return
  end
  self:Advance()
end

function AH:OnListUpdate()
  if not self.scanning or not self.expecting then
    return
  end

  local itemId = self.queue[self.qi]
  if not itemId then
    self.expecting = false
    self:Finish()
    return
  end

  self.expecting = false
  self:ProcessPage(itemId)
end

function AH:Finish()
  local ore = self.ore
  local results = self.results
  local mode = self.mode
  local cb = self.onComplete
  self:ResetJob()

  if not ore or not results then
    if cb then
      cb(nil, "Scan failed")
    end
    return
  end

  if mode == "buyout" then
    local fresh, freshnessError = PP.DB:GetFreshOre(ore.id)
    if not fresh or fresh.rec ~= "BUY" or fresh.lastScan ~= results.snapshotLastScan then
      if cb then
        cb(nil, freshnessError or PP.DB.STALE_ORE_ERROR)
      end
      if PP.UI then
        PP.UI:Refresh()
      end
      return
    end
    if cb then
      cb(results.best, results.best and nil or "No stack of 20 listed")
    end
    if PP.UI then
      PP.UI:Refresh()
    end
    return
  end

  if mode == "commit" then
    local hit = results.commitHit
    local fresh, freshnessError = PP.DB:GetFreshOre(ore.id)
    if not fresh or fresh.rec ~= "BUY" or fresh.lastScan ~= results.snapshotLastScan then
      if cb then
        cb(nil, freshnessError or PP.DB.STALE_ORE_ERROR)
      end
    elseif not hit then
      if cb then
        cb(nil, "Listing gone — scan again")
      end
    else
      if GetMoney() < hit.buyout then
        if cb then
          cb(nil, "Not enough gold")
        end
      else
        local ok, err, placed = InstantBuy(hit.index, hit.buyout)
        if ok then
          if cb then
            cb(placed or hit, nil)
          end
        else
          if cb then
            cb(nil, err or "Instant buy failed")
          end
        end
      end
    end
    if PP.UI then
      PP.UI:Refresh()
    end
    return
  end

  if results.gems then
    for gemId, price in pairs(results.gems) do
      PP.DB:SaveGem(gemId, price)
    end
  end

  local snapshot = PP.Economy.BuildSnapshot(ore, results)
  PP.DB:SaveOre(ore.id, snapshot)
  if PP.UI then
    local extra = ""
    if #snapshot.missing > 0 then
      extra = string.format(" · %d gem(s) unlisted", #snapshot.missing)
    end
    local cached = results.usedCache or 0
    if cached > 0 then
      extra = extra .. string.format(" · %d gems cached", cached)
    end
    PP.UI:SetStatus("Scan complete" .. extra)
    PP.UI:Refresh()
  end
end

function AH:BuildScanQueue(ore, force)
  local queue = { ore.id }
  local gems = { }
  local cached, live = 0, 0
  local seen = { [ore.id] = true }
  for _, gem in ipairs(ore.gems) do
    if not seen[gem.id] then
      seen[gem.id] = true
      -- Do not write `(not force) and GetFreshGem()`: `false ~= nil` is true in Lua.
      local fresh
      if not force then
        fresh = PP.DB:GetFreshGem(gem.id)
      end
      if type(fresh) == "number" and fresh > 0 then
        gems[gem.id] = fresh
        cached = cached + 1
      else
        queue[#queue + 1] = gem.id
        live = live + 1
      end
    end
  end
  return queue, gems, cached, live
end

function AH:StartScan(oreIndex, force)
  if self.scanning then
    if self.mode == "buyout" or self.mode == "commit" then
      return false
    end
    self:ResetJob()
  end
  if not IsAHShown() then
    if PP.UI then
      PP.UI:SetStatus("Open an Auctioneer to scan")
    end
    return false
  end
  local ore = PP.Data.GetOre(oreIndex)
  if not ore then
    return false
  end

  local queue, gems, cached, live = self:BuildScanQueue(ore, force)
  self.scanning = true
  self.mode = "scan"
  self.ore = ore
  self.queue = queue
  self.qi = 1
  self.page = 0
  self.cachedGems = cached
  self.liveGems = live
  self.results = { gems = gems, usedCache = cached }
  self.onComplete = nil
  if PP.UI then
    PP.UI:SetStatus(self:StatusText())
    PP.UI:RefreshButtons()
  end
  self:QueryCurrent()
  return true
end

function AH:FindBuyout(oreIndex, callback)
  if self.scanning then
    callback(nil, "Scan already running")
    return
  end
  if not IsAHShown() then
    callback(nil, "Auction House is closed")
    return
  end
  local ore = PP.Data.GetOre(oreIndex)
  if not ore then
    callback(nil, "Unknown ore")
    return
  end
  local snap, freshnessError = PP.DB:GetFreshOre(ore.id)
  if not snap then
    callback(nil, freshnessError)
    return
  end
  if snap.rec ~= "BUY" or not snap.be1 or snap.be1 <= 0 then
    callback(nil, "No profitable stack")
    return
  end

  self.scanning = true
  self.mode = "buyout"
  self.ore = ore
  self.queue = { ore.id }
  self.qi = 1
  self.page = 0
  self.results = { gems = {}, be1 = snap.be1, snapshotLastScan = snap.lastScan }
  self.onComplete = callback
  if PP.UI then
    PP.UI:SetStatus(self:StatusText())
    PP.UI:RefreshButtons()
  end
  self:QueryCurrent()
end

function AH:CommitBuyout(listing, callback)
  if self.scanning then
    callback(nil, "Scan already running")
    return
  end
  if not IsAHShown() then
    callback(nil, "Auction House is closed")
    return
  end
  if not listing or not listing.itemId or not listing.buyout then
    callback(nil, "No listing")
    return
  end
  local ore = self.ore
  -- Prefer the ore still selected in the UI.
  local selected = PP.Data.GetOre(PP:GetSelected())
  ore = selected or ore
  if not ore then
    callback(nil, "Unknown ore")
    return
  end
  local snap, freshnessError = PP.DB:GetFreshOre(ore.id)
  if not snap then
    callback(nil, freshnessError)
    return
  end
  if snap.rec ~= "BUY" or not listing.marketScan or listing.marketScan ~= snap.lastScan then
    callback(nil, PP.DB.STALE_ORE_ERROR)
    return
  end
  self.scanning = true
  self.mode = "commit"
  self.ore = ore
  self.commit = listing
  self.queue = { ore.id }
  self.qi = 1
  self.page = 0
  self.results = { gems = {}, be1 = snap.be1 or 0, snapshotLastScan = snap.lastScan }
  self.onComplete = callback
  if PP.UI then
    PP.UI:SetStatus("Placing buyout…")
    PP.UI:RefreshButtons()
  end
  self:QueryCurrent()
end
