ProspectProfit = ProspectProfit or {}
local PP = ProspectProfit
local UI = {}
PP.UI = UI

local BUY_COLOR = { 0.45, 0.92, 0.42 }
local SKIP_COLOR = { 0.95, 0.32, 0.28 }
local GOLD = { 0.95, 0.82, 0.38 }
local MUTED = { 0.72, 0.64, 0.48 }
local POS = { 0.48, 0.90, 0.42 }
local NEG = { 0.92, 0.38, 0.32 }

local function Solid(tex, r, g, b, a)
  if tex.SetColorTexture then
    tex:SetColorTexture(r, g, b, a)
  else
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(r, g, b, a or 1)
  end
end

local function Hairline(parent, anchorTop)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("LEFT", 18, 0)
  line:SetPoint("RIGHT", -18, 0)
  if anchorTop then
    line:SetPoint("TOP", anchorTop, "BOTTOM", 0, -6)
  end
  Solid(line, 0.72, 0.58, 0.22, 0.35)
  return line
end

local function Backdrop()
  return {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  }
end

local function ApplyBackdrop(frame, r, g, b, a)
  if frame.SetBackdrop then
    frame:SetBackdrop(Backdrop())
    frame:SetBackdropColor(r or 0.07, g or 0.06, b or 0.04, a or 0.97)
    frame:SetBackdropBorderColor(0.72, 0.58, 0.28, 0.9)
    return
  end
  if not frame.bg then
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    frame.bg = bg
  end
  Solid(frame.bg, r or 0.07, g or 0.06, b or 0.04, a or 0.97)
end

local function BigFont(fs, size)
  local file = GameFontNormalHuge:GetFont()
  fs:SetFont(file, size, "OUTLINE")
end

function UI:Create()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "ProspectProfitFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  frame:Hide()
  frame:EnableMouse(true)
  ApplyBackdrop(frame, 0.08, 0.07, 0.05, 0.98)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Prospecting")
  title:SetTextColor(unpack(GOLD))

  Hairline(frame, title)

  local footer = CreateFrame("Frame", nil, frame)
  footer:SetHeight(68)
  footer:SetPoint("BOTTOMLEFT", 18, 12)
  footer:SetPoint("BOTTOMRIGHT", -18, 12)

  local oreRow = CreateFrame("Frame", nil, frame)
  oreRow:SetPoint("TOPLEFT", 18, -36)
  oreRow:SetPoint("TOPRIGHT", -18, -36)
  oreRow:SetHeight(50)

  local prev = CreateFrame("Button", "ProspectProfitPrevButton", oreRow)
  prev:SetSize(40, 40)
  prev:SetPoint("LEFT", 4, 0)
  prev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
  prev:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  prev:SetScript("OnClick", function()
    PP:CycleOre(-1)
  end)

  local next = CreateFrame("Button", "ProspectProfitNextButton", oreRow)
  next:SetSize(40, 40)
  next:SetPoint("RIGHT", -4, 0)
  next:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  next:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  next:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  next:SetScript("OnClick", function()
    PP:CycleOre(1)
  end)

  local icon = oreRow:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("LEFT", prev, "RIGHT", 10, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local iconBorder = oreRow:CreateTexture(nil, "OVERLAY")
  iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  iconBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
  iconBorder:SetSize(58, 58)

  local oreName = oreRow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  oreName:SetPoint("LEFT", icon, "RIGHT", 14, 7)
  oreName:SetPoint("RIGHT", next, "LEFT", -10, 7)
  oreName:SetJustifyH("LEFT")
  oreName:SetTextColor(unpack(GOLD))

  local oreSkill = oreRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  oreSkill:SetPoint("TOPLEFT", oreName, "BOTTOMLEFT", 0, -3)
  oreSkill:SetTextColor(unpack(MUTED))

  local verdictBg = CreateFrame("Frame", nil, frame)
  verdictBg:SetPoint("TOPLEFT", oreRow, "BOTTOMLEFT", 0, -10)
  verdictBg:SetPoint("TOPRIGHT", oreRow, "BOTTOMRIGHT", 0, -10)
  verdictBg:SetHeight(54)

  local verdictFill = verdictBg:CreateTexture(nil, "BACKGROUND")
  verdictFill:SetAllPoints()
  Solid(verdictFill, 0.22, 0.08, 0.07, 0.92)

  local verdictEdge = verdictBg:CreateTexture(nil, "BORDER")
  verdictEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
  verdictEdge:SetPoint("TOPLEFT", 0, 0)
  verdictEdge:SetPoint("TOPRIGHT", 0, 0)
  verdictEdge:SetHeight(2)
  Solid(verdictEdge, 0.85, 0.28, 0.22, 0.95)
  local verdictEdgeB = verdictBg:CreateTexture(nil, "BORDER")
  verdictEdgeB:SetTexture("Interface\\Buttons\\WHITE8X8")
  verdictEdgeB:SetPoint("BOTTOMLEFT", 0, 0)
  verdictEdgeB:SetPoint("BOTTOMRIGHT", 0, 0)
  verdictEdgeB:SetHeight(2)
  Solid(verdictEdgeB, 0.85, 0.28, 0.22, 0.55)

  local verdict = verdictBg:CreateFontString(nil, "OVERLAY")
  BigFont(verdict, 28)
  verdict:SetPoint("CENTER", 0, 8)
  verdict:SetText("SKIP")

  local verdictWhy = verdictBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  verdictWhy:SetPoint("TOP", verdict, "BOTTOM", 0, -2)
  verdictWhy:SetTextColor(unpack(MUTED))
  verdictWhy:SetText("Scan to compare ore cost vs expected net")

  local stats = CreateFrame("Frame", nil, frame)
  stats:SetPoint("TOPLEFT", verdictBg, "BOTTOMLEFT", 16, -10)
  stats:SetPoint("TOPRIGHT", verdictBg, "BOTTOMRIGHT", -16, -10)
  stats:SetHeight(80)

  local function StatRow(index, labelText)
    local row = CreateFrame("Frame", nil, stats)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", stats, "TOPLEFT", 0, -((index - 1) * 26))
    row:SetPoint("TOPRIGHT", stats, "TOPRIGHT", 0, -((index - 1) * 26))
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(unpack(MUTED))
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    value:SetPoint("RIGHT", 0, 0)
    value:SetText("—")
    value:SetTextColor(1, 0.96, 0.82)
    return row, value, label
  end

  local _, costValue = StatRow(1, "You pay for 20 ore")
  local _, gemsValue = StatRow(2, "Expected net from 20 ore")
  local _, profitValue, profitLabel = StatRow(3, "Expected profit")

  local status = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  status:SetPoint("TOPLEFT", 2, 0)
  status:SetPoint("TOPRIGHT", -2, 0)
  status:SetJustifyH("CENTER")
  status:SetTextColor(unpack(MUTED))
  status:SetText("Scan the market for live prices")

  local scan = CreateFrame("Button", "ProspectProfitScanButton", footer, "UIPanelButtonTemplate")
  scan:SetSize(150, 34)
  scan:SetPoint("BOTTOMLEFT", 0, 0)
  scan:SetText("Scan Prices")
  scan:SetScript("OnClick", function()
    PP:ScanMarket()
  end)

  local how = CreateFrame("Button", "ProspectProfitHowButton", footer, "UIPanelButtonTemplate")
  how:SetSize(88, 34)
  how:SetPoint("BOTTOM", 0, 0)
  how:SetText("How?")
  how:SetScript("OnClick", function()
    PP.UI:ShowMath()
  end)

  local buy = CreateFrame("Button", "ProspectProfitBuyoutButton", footer, "UIPanelButtonTemplate")
  buy:SetSize(150, 34)
  buy:SetPoint("BOTTOMRIGHT", 0, 0)
  buy:SetText("Buy 20 Ore")
  buy:SetScript("OnClick", function()
    PP:BuyoutStack()
  end)

  self.frame = frame
  self.icon = icon
  self.oreName = oreName
  self.oreSkill = oreSkill
  self.verdict = verdict
  self.verdictWhy = verdictWhy
  self.verdictBg = verdictBg
  self.verdictFill = verdictFill
  self.verdictEdge = verdictEdge
  self.verdictEdgeB = verdictEdgeB
  self.costValue = costValue
  self.gemsValue = gemsValue
  self.profitValue = profitValue
  self.profitLabel = profitLabel
  self.status = status
  self.scan = scan
  self.how = how
  self.buy = buy
  self.stickyStatus = nil

  self:CreateConfirm()
  self:CreateMath()
  self:Refresh()
end

function UI:CreateConfirm()
  local parent = self.frame
  local dlg = CreateFrame("Frame", "ProspectProfitConfirm", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  dlg:SetSize(360, 160)
  dlg:SetPoint("CENTER")
  dlg:SetFrameStrata("FULLSCREEN_DIALOG")
  dlg:EnableMouse(true)
  dlg:Hide()
  ApplyBackdrop(dlg)

  local text = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  text:SetPoint("TOPLEFT", 18, -20)
  text:SetPoint("TOPRIGHT", -18, -20)
  text:SetJustifyH("CENTER")
  text:SetText("Buy this stack?")

  local yes = CreateFrame("Button", "ProspectProfitConfirmYes", dlg, "UIPanelButtonTemplate")
  yes:SetSize(120, 40)
  yes:SetPoint("BOTTOMLEFT", 28, 18)
  yes:SetText("Buy")

  local no = CreateFrame("Button", "ProspectProfitConfirmNo", dlg, "UIPanelButtonTemplate")
  no:SetSize(120, 40)
  no:SetPoint("BOTTOMRIGHT", -28, 18)
  no:SetText("Cancel")
  no:SetScript("OnClick", function()
    dlg:Hide()
    self.pendingListing = nil
    self:SetStatus("Buyout cancelled")
    self:RefreshButtons()
  end)

  yes:SetScript("OnClick", function()
    local listing = self.pendingListing
    dlg:Hide()
    self.pendingListing = nil
    if not listing then
      self:SetStatus("Buyout cancelled")
      self:RefreshButtons()
      return
    end
    PP.AH:CommitBuyout(listing, function(hit, err)
      if hit then
        self:SetStatus("Buyout sent · " .. PP.Economy.FormatMoney(hit.buyout))
      else
        self:SetStatus(err or "Buyout failed")
      end
      self:RefreshButtons()
    end)
  end)

  self.confirm = dlg
  self.confirmText = text
end

function UI:ShowConfirm(listing)
  local name = PP.Data.GetName(listing.itemId) or "ore"
  self.pendingListing = listing
  self.confirmText:SetText(string.format(
    "Buy 20 %s now\nfor %s?",
    name,
    PP.Economy.FormatMoney(listing.buyout)
  ))
  if self.math then
    self.math:Hide()
  end
  self.confirm:Show()
end

function UI:CreateMath()
  local dlg = CreateFrame("Frame", "ProspectProfitMath", self.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  dlg:SetAllPoints(self.frame)
  dlg:SetFrameLevel(self.frame:GetFrameLevel() + 30)
  dlg:EnableMouse(true)
  dlg:Hide()
  ApplyBackdrop(dlg, 0.08, 0.07, 0.05, 0.98)

  local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetTextColor(unpack(GOLD))

  local blurb = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  blurb:SetPoint("TOP", title, "BOTTOM", 0, -4)
  blurb:SetTextColor(unpack(MUTED))
  blurb:SetText("Expected quantity × AH price, less the 5% faction AH seller cut.")

  local rows = {}
  for i = 1, 18 do
    local row = CreateFrame("Frame", nil, dlg)
    row:SetHeight(13)
    row:SetPoint("TOPLEFT", 16, -34 - i * 13)
    row:SetPoint("TOPRIGHT", -16, -34 - i * 13)
    local left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    left:SetPoint("LEFT")
    left:SetTextColor(unpack(MUTED))
    local mid = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mid:SetPoint("CENTER")
    mid:SetTextColor(1, 0.96, 0.82)
    local right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    right:SetPoint("RIGHT")
    right:SetTextColor(1, 0.96, 0.82)
    rows[i] = { frame = row, left = left, mid = mid, right = right }
  end

  local close = CreateFrame("Button", "ProspectProfitMathClose", dlg, "UIPanelButtonTemplate")
  close:SetSize(120, 32)
  close:SetPoint("BOTTOM", 0, 12)
  close:SetText("Back")
  close:SetScript("OnClick", function()
    dlg:Hide()
  end)

  self.math = dlg
  self.mathTitle = title
  self.mathRows = rows
end

function UI:ShowMath()
  if not self.math then
    return
  end
  if self.confirm then
    self.confirm:Hide()
  end
  local ore = PP.Data.GetOre(PP:GetSelected())
  if not ore then
    return
  end
  local snap = PP.DB:GetOre(ore.id)
  local expl = PP.Economy.Explain(ore, snap)
  self.mathTitle:SetText((expl.rec == "BUY" and "Why BUY" or "Why SKIP") .. " · " .. (PP.Data.GetName(ore.id) or ""))

  local i = 1
  local function put(left, mid, right, r, g, b)
    local row = self.mathRows[i]
    if not row then
      return
    end
    row.frame:Show()
    row.left:SetText(left or "")
    row.mid:SetText(mid or "")
    row.right:SetText(right or "")
    if r then
      row.right:SetTextColor(r, g, b)
    else
      row.right:SetTextColor(1, 0.96, 0.82)
    end
    i = i + 1
  end

  for _, line in ipairs(expl.lines) do
    local name = PP.Data.GetName(line.id) or ("#" .. line.id)
    if line.rare then
      name = name .. "  (rare)"
    end
    local quantity = PP.Economy.FormatQuantity(line.expectedQuantity)
    local price = line.price and PP.Economy.FormatMoney(line.price) or "no listing"
    put(name, quantity .. " expected  ×  " .. price, "=  " .. PP.Economy.FormatMoney(line.netContrib))
  end
  put("Expected net per prospect", "", PP.Economy.FormatMoney(expl.netEV))
  put("× 4  →  expected net from 20", "", PP.Economy.FormatMoney(expl.expectedNet20))
  put("You pay for 20 ore", "", PP.Economy.FormatMoney(expl.cost))
  if expl.expectedProfit and expl.expectedProfit < 0 then
    put("Expected loss", "", PP.Economy.FormatMoney(expl.expectedProfit), unpack(NEG))
  else
    put("Expected profit", "", PP.Economy.FormatMoney(expl.expectedProfit), unpack(POS))
  end
  put(
    "BUY safety rule",
    string.format("%.0f%% ROI + %s", expl.minROI * 100, PP.Economy.FormatMoney(expl.minProfit)),
    expl.rec
  )

  while i <= #self.mathRows do
    self.mathRows[i].frame:Hide()
    i = i + 1
  end
  self.math:Show()
end

function UI:SetStatus(text)
  self.stickyStatus = text
  if self.status then
    self.status:SetText(text or "")
  end
end

function UI:RefreshButtons()
  if not self.frame then
    return
  end
  local busy = PP.AH:IsBusy()
  local confirmOpen = self.confirm and self.confirm:IsShown()
  -- Keep buttons clickable (ConsolePort cannot activate disabled widgets).
  -- Scan/Buyout still no-op with a status message if the AH is closed.
  if not busy and not confirmOpen then
    self.scan:Enable()
  else
    self.scan:Disable()
  end
  local ore = PP.Data.GetOre(PP:GetSelected())
  local snap = ore and PP.DB:GetFreshOre(ore.id)
  local canBuy = not busy and not confirmOpen and snap and snap.rec == "BUY"
  if canBuy then
    self.buy:Enable()
  else
    self.buy:Disable()
  end
end

function UI:Refresh()
  if not self.frame then
    return
  end
  local index = PP:GetSelected()
  local ore = PP.Data.GetOre(index)
  if not ore then
    return
  end

  self.icon:SetTexture(PP.Data.GetIcon(ore.id))
  self.oreName:SetText(PP.Data.GetName(ore.id) or "?")
  self.oreSkill:SetText(string.format("Jewelcrafting %d+", ore.skill))

  local snap = PP.DB:GetOre(ore.id)
  local rec = snap and snap.rec or "SKIP"
  local color = rec == "BUY" and BUY_COLOR or SKIP_COLOR
  self.verdict:SetText(rec)
  self.verdict:SetTextColor(unpack(color))
  if rec == "BUY" then
    local minROI = (snap.minROI or PP.Economy.Policy.minROI) * 100
    local minProfit = snap.minProfit or PP.Economy.Policy.minProfit
    Solid(self.verdictFill, 0.08, 0.22, 0.10, 0.92)
    Solid(self.verdictEdge, 0.35, 0.82, 0.32, 0.95)
    Solid(self.verdictEdgeB, 0.35, 0.82, 0.32, 0.45)
    self.verdictWhy:SetText(string.format(
      "Expected net clears %.0f%% ROI and %s profit",
      minROI,
      PP.Economy.FormatMoney(minProfit)
    ))
  else
    Solid(self.verdictFill, 0.22, 0.08, 0.07, 0.92)
    Solid(self.verdictEdge, 0.85, 0.28, 0.22, 0.95)
    Solid(self.verdictEdgeB, 0.85, 0.28, 0.22, 0.45)
    if not snap then
      self.verdictWhy:SetText("Scan to compare ore cost vs expected net")
    elseif snap.decisionReason == "MIN_ROI" then
      self.verdictWhy:SetText(string.format(
        "Expected ROI is below the %.0f%% safety margin",
        (snap.minROI or PP.Economy.Policy.minROI) * 100
      ))
    elseif snap.decisionReason == "MIN_PROFIT" then
      self.verdictWhy:SetText(
        "Expected profit is below the "
          .. PP.Economy.FormatMoney(snap.minProfit or PP.Economy.Policy.minProfit)
          .. " minimum"
      )
    else
      self.verdictWhy:SetText("Expected net does not justify this purchase")
    end
  end

  -- Same unit everywhere: one stack of 20.
  self.costValue:SetText(PP.Economy.FormatMoney(PP.Economy.StackPrice(snap)))
  self.gemsValue:SetText(PP.Economy.FormatMoney(snap and snap.be20 or nil))

  local profit = snap and snap.profit or nil
  self.profitValue:SetText(PP.Economy.FormatMoney(profit))
  if profit and profit > 0 then
    self.profitLabel:SetText("Expected profit")
    self.profitValue:SetTextColor(unpack(POS))
  elseif profit and profit < 0 then
    self.profitLabel:SetText("Expected loss")
    self.profitValue:SetTextColor(unpack(NEG))
  else
    self.profitLabel:SetText("Expected profit")
    self.profitValue:SetTextColor(1, 0.96, 0.82)
  end

  if not self.stickyStatus or self.stickyStatus == "" then
    local ah = PP.AH:IsOpen()
    local age = PP.Economy.FormatAge(snap and snap.lastScan)
    local conn = ah and "AH connected" or "Offline"
    local missing = ""
    if snap and snap.missing and #snap.missing > 0 then
      missing = string.format(" · %d output(s) unlisted", #snap.missing)
    end
    if not snap then
      self.status:SetText(ah and "AH connected · no scan yet" or "Offline · no saved prices")
    else
      self.status:SetText(string.format("Last scan · %s · %s%s", age, conn, missing))
    end
  elseif PP.AH:IsBusy() then
    self.status:SetText(PP.AH:StatusText() or self.stickyStatus)
  else
    self.status:SetText(self.stickyStatus)
  end

  self:RefreshButtons()
end

local HIDE_WHEN_PROSPECT = {
  "AuctionFrameBrowse",
  "AuctionFrameBid",
  "AuctionFrameAuctions",
  "BrowsePrevPageButton",
  "BrowseNextPageButton",
  "BrowseSearchButton",
  "BrowseResetButton",
  "BrowseIsUsableCheckButton",
  "ShowOnPlayerCheckButton",
  "BrowseDropDown",
  "BrowseName",
  "BrowseMinLevel",
  "BrowseMaxLevel",
  "BrowseLevelHyphen",
  "AuctionFrameFilters",
  "BrowseFilterScrollFrame",
  "BrowseQualitySort",
  "BrowseLevelSort",
  "BrowseDurationSort",
  "BrowseHighBidderSort",
  "BrowseCurrentBidSort",
  "BrowseScrollFrame",
  "BrowseNoResultsText",
  "BrowseSearchCountText",
  "BrowsePriceOptionsButtonFrame",
}

local function SuppressFrame(f)
  if not f or not f.Hide then
    return
  end
  f:Hide()
  if f.ppSuppressed then
    return
  end
  f.ppSuppressed = true
  hooksecurefunc(f, "Show", function(self)
    if ProspectProfit and ProspectProfit.UI and ProspectProfit.UI:IsShown() then
      self:Hide()
    end
  end)
end

local function HideBlizzardAHBits()
  for _, name in ipairs(HIDE_WHEN_PROSPECT) do
    SuppressFrame(_G[name])
  end
  if AuctionFrameBrowse then
    local kids = { AuctionFrameBrowse:GetChildren() }
    for i = 1, #kids do
      SuppressFrame(kids[i])
    end
    AuctionFrameBrowse:Hide()
  end
end

local function SetBrowseTextures()
  if not AuctionFrameTopLeft then
    return
  end
  AuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopLeft")
  AuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-Top")
  AuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopRight")
  AuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-BotLeft")
  AuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-Bot")
  AuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-BotRight")
end

local function LastForeignTab(ourTab)
  local last
  for i = 1, 16 do
    local t = _G["AuctionFrameTab" .. i]
    if t and t ~= ourTab and t:IsShown() then
      last = t
    end
  end
  return last
end

local function ClickSound()
  if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
  else
    pcall(PlaySound, "igCharacterInfoTab")
  end
end

local function DeselectAHTabs()
  for i = 1, 16 do
    local t = _G["AuctionFrameTab" .. i]
    if t and PanelTemplates_DeselectTab then
      PanelTemplates_DeselectTab(t)
    end
  end
end

function UI:AttachToAuctionHouse()
  if not AuctionFrame or not self.frame then
    return
  end
  local frame = self.frame
  frame:SetParent(AuctionFrame)
  frame:SetFrameLevel(AuctionFrame:GetFrameLevel() + 20)
  frame:ClearAllPoints()
  -- Cover the browse filter well on the left as well as the main pane.
  frame:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 18, -73)
  frame:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -10, 36)
  self.attached = true
end

function UI:PlaceTab()
  if not self.tab or not AuctionFrame then
    return
  end
  self.tab:SetParent(AuctionFrame)
  self.tab:Show()
  self.tab:SetFrameLevel(AuctionFrame:GetFrameLevel() + 8)

  local best, bestRight
  local children = { AuctionFrame:GetChildren() }
  for i = 1, #children do
    local child = children[i]
    if child ~= self.tab and child.IsObjectType and child:IsObjectType("Button") and child:IsShown() then
      local bottom, afBottom = child:GetBottom(), AuctionFrame:GetBottom()
      if bottom and afBottom and math.abs(bottom - afBottom) < 28 then
        local right = child:GetRight()
        if right and (not bestRight or right > bestRight) then
          best, bestRight = child, right
        end
      end
    end
  end
  if not best then
    best = LastForeignTab(self.tab)
  end

  self.tab:ClearAllPoints()
  if best then
    self.tab:SetPoint("TOPLEFT", best, "TOPRIGHT", -8, 0)
  else
    self.tab:SetPoint("TOPLEFT", AuctionFrame, "BOTTOMLEFT", 200, 12)
  end
end

function UI:InstallTab()
  if not AuctionFrame then
    return
  end
  self:AttachToAuctionHouse()
  if self.tab then
    self:PlaceTab()
    return
  end

  -- Independent of AuctionFrame.numTabs so TSM cannot hide us.
  local tab
  local ok = pcall(function()
    tab = CreateFrame("Button", "ProspectProfitAHTab", AuctionFrame, "AuctionTabTemplate")
  end)
  if not ok or not tab then
    tab = CreateFrame("Button", "ProspectProfitAHTab", AuctionFrame, "UIPanelButtonTemplate")
    tab:SetSize(80, 22)
  end
  if not tab then
    return
  end
  tab:SetText("Prospect")
  tab:SetScript("OnClick", function()
    ClickSound()
    DeselectAHTabs()
    if PanelTemplates_SelectTab then
      PanelTemplates_SelectTab(tab)
    end
    UI:OnTabSelected()
  end)

  if not self.hookedTab then
    self.hookedTab = true
    hooksecurefunc("AuctionFrameTab_OnClick", function(clicked)
      if not UI.tab or clicked == UI.tab then
        return
      end
      if PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(UI.tab)
      end
      UI:OnTabDeselected()
    end)
  end

  self.tab = tab
  self:PlaceTab()
end

function UI:OnTabSelected()
  HideBlizzardAHBits()
  SetBrowseTextures()
  self:PlaceTab()
  if AuctionPortraitTexture then
    SetPortraitToTexture(AuctionPortraitTexture, "Interface\\Icons\\INV_Misc_Gem_Variety_01")
  end
  self:AttachToAuctionHouse()
  self.stickyStatus = nil
  self.frame:Show()
  self:Refresh()
  PP:DebouncedScan()
end

function UI:OnTabDeselected()
  if self.confirm then
    self.confirm:Hide()
  end
  if self.math then
    self.math:Hide()
  end
  self.pendingListing = nil
  if self.frame then
    self.frame:Hide()
  end
end

function UI:SelectTab()
  if not AuctionFrame or not AuctionFrame:IsShown() then
    PP:Print("Talk to an Auctioneer, then open the Prospect tab.")
    return false
  end
  self:InstallTab()
  if not self.tab then
    return false
  end
  if self.tab.Click then
    self.tab:Click()
  else
    self.tab:GetScript("OnClick")(self.tab)
  end
  return true
end

function UI:Show()
  self:SelectTab()
end

function UI:Hide()
  self:OnTabDeselected()
  if AuctionFrame and AuctionFrame:IsShown() and AuctionFrameTab1 then
    if AuctionFrameTab_OnClick then
      AuctionFrameTab_OnClick(AuctionFrameTab1)
    end
  end
end

function UI:Toggle()
  if self:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

function UI:IsShown()
  return self.frame and self.frame:IsShown()
end
