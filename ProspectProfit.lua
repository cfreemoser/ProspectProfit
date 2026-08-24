ProspectProfit = ProspectProfit or {}
local PP = ProspectProfit

BINDING_HEADER_PROSPECTPROFIT = "ProspectProfit"
BINDING_NAME_PROSPECTPROFITTOGGLE = "Toggle window"
BINDING_NAME_PROSPECTPROFITPREVORE = "Previous ore"
BINDING_NAME_PROSPECTPROFITNEXTORE = "Next ore"
BINDING_NAME_PROSPECTPROFITSCAN = "Scan market"
BINDING_NAME_PROSPECTPROFITBUYOUT = "Buyout stack"

local SCAN_DEBOUNCE = 0.45

function PP:GetSelected()
  return self.DB:GetSelected()
end

function PP:CycleOre(delta)
  local n = #self.Data.Ores
  local i = self:GetSelected()
  i = ((i - 1 + delta) % n) + 1
  self.DB:SetSelected(i)
  if self.UI then
    if self.UI.confirm then
      self.UI.confirm:Hide()
      self.UI.pendingListing = nil
    end
    self.UI.stickyStatus = nil
    self.UI:Refresh()
  end
  if self.AH:IsOpen() and self.UI and self.UI:IsShown() then
    self:DebouncedScan()
  end
end

function PP:DebouncedScan()
  self.scanGen = (self.scanGen or 0) + 1
  local gen = self.scanGen
  local delay = SCAN_DEBOUNCE
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, function()
      if self.scanGen == gen then
        self:ScanMarket(true)
      end
    end)
    return
  end
  local f = CreateFrame("Frame")
  local t = 0
  f:SetScript("OnUpdate", function(frame, elapsed)
    t = t + elapsed
    if t >= delay then
      frame:SetScript("OnUpdate", nil)
      if self.scanGen == gen then
        self:ScanMarket(true)
      end
    end
  end)
end

function PP:ScanMarket(silent)
  if silent and (not self.UI or not self.UI:IsShown()) then
    return
  end
  if not silent and self.UI and not self.UI:IsShown() then
    if not self.UI:SelectTab() then
      return
    end
  end
  if self.AH:IsBusy() then
    if not silent and self.UI then
      self.UI:SetStatus("Scan already running")
    end
    return
  end
  -- Manual Scan (not silent) force-refreshes gems even if the cache is fresh.
  self.AH:StartScan(self:GetSelected(), not silent)
end

function PP:BuyoutStack()
  if not self.AH:IsOpen() then
    if self.UI then
      self.UI:SetStatus("Open an Auctioneer to buy")
    end
    return
  end
  if self.AH:IsBusy() then
    return
  end
  if self.UI and self.UI.confirm and self.UI.confirm:IsShown() then
    return
  end
  local ore = self.Data.GetOre(self:GetSelected())
  local snap = ore and self.DB:GetOre(ore.id)
  if not snap or snap.rec ~= "BUY" then
    if self.UI then
      self.UI:SetStatus("No profitable stack")
    end
    return
  end
  self.AH:FindBuyout(self:GetSelected(), function(listing, err)
    if listing then
      self.UI:ShowConfirm(listing)
      self.UI:SetStatus("Confirm buyout")
    else
      self.UI:SetStatus(err or "No profitable listing found")
    end
    self.UI:RefreshButtons()
  end)
end

function PP:ToggleWindow()
  if self.UI then
    self.UI:Toggle()
  end
end

function PP:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffedd14fProspectProfit:|r " .. tostring(msg))
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == "Blizzard_AuctionUI" then
      PP.AH:HookAuctionFrame()
      return
    end
    if name ~= "ProspectProfit" then
      return
    end
    PP.DB:Init()
    PP.UI:Create()
    PP.Data.Prefetch()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("AUCTION_HOUSE_SHOW")
    self:RegisterEvent("AUCTION_HOUSE_CLOSED")
    self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    return
  end

  if event == "PLAYER_LOGIN" then
    PP.Data.Prefetch()
    PP.AH:HookAuctionFrame()
    if PP.UI then
      PP.UI:Refresh()
    end
    PP:Print("Ready. At the AH, open the Prospect tab. Bind Previous/Next ore to bumpers.")
    return
  end

  if event == "GET_ITEM_INFO_RECEIVED" then
    if PP.UI and PP.UI:IsShown() then
      PP.UI:Refresh()
    end
    return
  end

  if event == "AUCTION_HOUSE_SHOW" then
    PP.AH:OnShown()
    return
  end

  if event == "AUCTION_HOUSE_CLOSED" then
    PP.AH:OnClosed()
    return
  end

  if event == "AUCTION_ITEM_LIST_UPDATE" then
    PP.AH:OnListUpdate()
  end
end)

SLASH_PROSPECTPROFIT1 = "/prospect"
SLASH_PROSPECTPROFIT2 = "/prospectprofit"
SlashCmdList.PROSPECTPROFIT = function(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "scan" then
    PP.UI:Show()
    PP:ScanMarket()
    return
  end
  if msg == "next" then
    PP:CycleOre(1)
    return
  end
  if msg == "prev" then
    PP:CycleOre(-1)
    return
  end
  PP:ToggleWindow()
end
