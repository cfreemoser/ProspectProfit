-- Unit tests for prospecting expected-value / BUY-SKIP math.
-- Run from repo root: lua tests/test_economy.lua

local here = arg and arg[0] and arg[0]:match("(.+)[/\\]") or "."
local root = here .. "/.."

function GetItemInfo()
  return nil
end

function GetItemIcon()
  return nil
end

function time()
  return os.time()
end

dofile(root .. "/ProspectProfitData.lua")
dofile(root .. "/ProspectProfitEconomy.lua")

local Eco = ProspectProfit.Economy
local Data = ProspectProfit.Data
local gold = 10000
local fails, passed = 0, 0

local function eq(a, b, eps)
  eps = eps or 0.01
  return a ~= nil and b ~= nil and math.abs(a - b) < eps
end

local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    fails = fails + 1
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

local function oreById(id)
  for _, ore in ipairs(Data.Ores) do
    if ore.id == id then
      return ore
    end
  end
end

local function outputById(ore, id)
  for _, output in ipairs(ore.outputs) do
    if output.id == id then
      return output
    end
  end
end

-- Formatting helpers
check(Eco.FormatMoney(nil) == "—", "nil money is em dash")
check(Eco.FormatMoney(0) == "0c", "zero copper")
check(Eco.FormatMoney(123456) == "12g 34s 56c", "full money")
check(Eco.FormatMoney(-150) == "-1s 50c", "negative money")
check(Eco.FormatQuantity(1) == "1", "whole expected quantity")
check(Eco.FormatQuantity(0.18) == "0.18", "fractional expected quantity")
check(Eco.FormatAge(nil) == "never", "nil age")
check(Eco.FormatAge(time()) == "just now", "current age")
check(Eco.FormatAge(time() - 7200) == "2h ago", "hour age")

-- Stack pricing
check(Eco.StackPrice(nil) == nil, "nil snapshot")
check(Eco.StackPrice({ oreStack20 = 50 * gold }) == 50 * gold, "listed stack preferred")
check(Eco.StackPrice({ oreMin = 2 * gold }) == 40 * gold, "unit fallback")

-- The AH buyout path receives the already safety-adjusted per-unit limit.
check(not Eco.IsListingProfitable(nil, 20, 1000), "nil buyout")
check(not Eco.IsListingProfitable(0, 20, 1000), "bid-only listing")
check(not Eco.IsListingProfitable(1000, 0, 1000), "zero count")
check(Eco.IsListingProfitable(20000, 20, 1000), "limit boundary is eligible")
check(not Eco.IsListingProfitable(20001, 20, 1000), "over limit is ineligible")

check(eq(Eco.Policy.sellerCut, 0.05), "default faction AH seller cut is 5%")
check(eq(Eco.Policy.minROI, 0.10), "default minimum ROI is 10%")
check(Eco.Policy.minProfit == gold, "default minimum expected profit is 1g")

local copper = oreById(2770)
check(copper ~= nil, "copper exists")

-- Linear expectation and faction-AH net proceeds.
do
  local r = Eco.Compute(copper, {
    gems = { [774] = 1 * gold, [818] = 2 * gold, [1210] = 10 * gold },
    oreStack20 = 8 * gold,
  })
  -- Gross/prospect = .5*1g + .5*2g + .1*10g = 2.5g.
  check(eq(r.grossEV, 2.5 * gold), "gross expected value")
  check(eq(r.netEV, 2.375 * gold), "5% seller cut produces net value")
  check(eq(r.expectedNet20, 9.5 * gold), "20 ore is four prospects")
  check(eq(r.expectedProfit, 1.5 * gold), "expected net less ore cost")
  check(eq(r.expectedROI, 0.1875), "expected ROI uses purchase cost")
  check(r.rec == "BUY" and r.decisionReason == "BUY", "safe expected return is BUY")
  check(eq(r.breakEven1, 0.475 * gold), "net break-even per ore")
  check(eq(r.be20, r.expectedNet20), "legacy be20 is expected net")
  check(eq(r.profit, r.expectedProfit), "legacy profit is expected profit")
end

-- A listing below gross output value but above net proceeds must not become BUY.
do
  local r = Eco.Compute(copper, {
    gems = { [774] = 1 * gold, [818] = 2 * gold, [1210] = 10 * gold },
    oreStack20 = 9.6 * gold,
  })
  check(10 * gold > r.oreStack20, "gross outputs exceed fee-boundary cost")
  check(eq(r.expectedNet20, 9.5 * gold), "net remains 9.5g")
  check(r.expectedProfit < 0 and r.rec == "SKIP", "seller cut prevents false BUY")
end

-- Tiny positive EV is rejected by the explicit minimum-profit rule.
do
  local r = Eco.Compute(copper, {
    gems = { [774] = 1 * gold, [818] = 2 * gold, [1210] = 10 * gold },
    oreStack20 = 9.45 * gold,
  })
  check(r.expectedProfit > 0, "tiny expected profit is positive")
  check(r.expectedProfit < r.minProfit, "tiny expected profit is below floor")
  check(r.rec == "SKIP" and r.decisionReason == "MIN_PROFIT", "profit floor rejects tiny EV")
end

-- A meaningful absolute profit can still fail the ROI safety margin.
do
  local r = Eco.Compute(copper, {
    gems = { [774] = 10 * gold, [818] = 20 * gold, [1210] = 100 * gold },
    oreStack20 = 87 * gold,
  })
  check(r.expectedProfit > r.minProfit, "absolute profit clears floor")
  check(r.expectedROI < r.minROI, "ROI is below threshold")
  check(r.rec == "SKIP" and r.decisionReason == "MIN_ROI", "ROI floor rejects listing")
  check(eq(r.maxBuy20, r.expectedNet20 / 1.10), "buy limit uses ROI constraint")
  check(eq(r.be1, r.maxBuy20 / 20), "AH alias uses safety-adjusted unit limit")
end

-- Policy inputs are configurable without changing saved-variable schemas.
do
  local r = Eco.Compute(copper, {
    gems = { [774] = 10 * gold, [818] = 20 * gold, [1210] = 100 * gold },
    oreStack20 = 80 * gold,
  }, {
    sellerCut = 0.15,
    minROI = 0.20,
    minProfit = 5 * gold,
  })
  check(eq(r.sellerCut, 0.15), "seller-cut override")
  check(eq(r.minROI, 0.20), "ROI override")
  check(r.minProfit == 5 * gold, "profit override")
  check(eq(r.netEV, r.grossEV * 0.85), "override applies to proceeds")
end

-- Missing output prices are conservatively worth zero and remain visible.
do
  local r = Eco.Compute(copper, {
    gems = { [774] = 100 },
    oreStack20 = 1,
  })
  check(eq(r.grossEV, 50), "only priced output contributes")
  check(#r.missing == 3, "missing outputs reported")
end

do
  local r = Eco.Compute(copper, {
    gems = { [774] = 1 * gold, [818] = 2 * gold, [1210] = 10 * gold },
  })
  check(r.expectedProfit == nil, "no ore cost means no profit")
  check(r.rec == "SKIP" and r.decisionReason == "NO_ORE_PRICE", "no cost is SKIP")
end

-- Corrected, auditable TBC output tables. Values are expected units per 5 ore.
local expected = {
  [2770] = { [774] = .50, [818] = .50, [1210] = .10, [24186] = 1 },
  [2771] = { [1705] = .375, [1206] = .375, [1210] = .375, [7909] = .0333, [3864] = .0333, [1529] = .0333, [24188] = 1 },
  [2772] = { [1705] = .35, [3864] = .35, [1529] = .35, [7910] = .05, [7909] = .05, [24190] = 1 },
  [3858] = { [7910] = .35, [7909] = .35, [3864] = .35, [12361] = .025, [12799] = .025, [12800] = .025, [12364] = .025, [24234] = 1 },
  [10620] = { [7910] = .30, [12364] = .16, [12800] = .16, [12361] = .16, [12799] = .16, [23077] = .0166, [23079] = .0166, [21929] = .0166, [23112] = .0166, [23107] = .0166, [23117] = .0166, [24235] = 1 },
  [23424] = { [23077] = .18, [23079] = .18, [21929] = .18, [23112] = .18, [23107] = .18, [23117] = .18, [23436] = .013, [23438] = .013, [23439] = .013, [23440] = .013, [23441] = .013, [23437] = .013, [24242] = 1 },
  [23425] = { [23077] = .18, [23079] = .18, [21929] = .18, [23112] = .18, [23107] = .18, [23117] = .18, [23436] = .04, [23438] = .04, [23439] = .04, [23440] = .04, [23441] = .04, [23437] = .04, [24243] = 1 },
}

check(#Data.Ores == 7, "only seven prospectable ores")
check(oreById(23426) == nil, "Khorium is not prospectable")
check(Data.Names[24186] == "Copper Powder", "classic powder has fallback name")
check(Data.Names[24243] == "Adamantite Powder", "Adamantite Powder has fallback name")
for oreId, outputs in pairs(expected) do
  local ore = oreById(oreId)
  check(ore ~= nil, "ore table exists for " .. oreId)
  check(ore and ore.outputs == ore.gems, "legacy gems alias for " .. oreId)
  local count = 0
  for outputId, quantity in pairs(outputs) do
    count = count + 1
    local output = outputById(ore, outputId)
    check(output ~= nil, "output " .. outputId .. " exists for " .. oreId)
    check(output and eq(output.expectedQuantity, quantity, 0.00001), "expected quantity for " .. outputId)
  end
  check(#ore.outputs == count, "no extra outputs for " .. oreId)
end
check(Data.Ores[6].id == 23424, "slot 6 is Fel Iron")
check(Data.Ores[7].id == 23425, "slot 7 is Adamantite")

-- Adamantite Powder contributes one expected unit to every prospect.
do
  local adamantite = oreById(23425)
  local r = Eco.Compute(adamantite, {
    gems = { [24243] = 2 * gold },
    oreStack20 = 1,
  })
  check(eq(r.grossEV, 2 * gold), "one expected powder contributes its full unit price")
  check(eq(r.netEV, 1.9 * gold), "powder proceeds receive seller cut")
  check(eq(r.expectedNet20, 7.6 * gold), "four prospects produce four expected powder")
  check(#r.missing == 12, "unpriced gems remain reported beside powder")
end

-- Scan IDs and UI-facing explanation fields include all outputs.
do
  local adamantite = oreById(23425)
  local ids = Data.UniqueScanIds(adamantite)
  check(#ids == 14, "Adamantite scan queue is ore plus 13 outputs")
  check(ids[1] == adamantite.id, "ore is first scan ID")
  check(ids[#ids] == 24243, "powder is scanned")

  local snap = Eco.BuildSnapshot(copper, {
    gems = { [774] = 1 * gold, [818] = 2 * gold, [1210] = 10 * gold },
    oreStack20 = 8 * gold,
  })
  local expl = Eco.Explain(copper, snap)
  check(type(snap.lastScan) == "number", "snapshot has timestamp")
  check(snap.policyVersion == Eco.PolicyVersion, "snapshot has current policy version")
  check(snap.outputs[774] == gold, "snapshot exposes output prices")
  check(#expl.lines == 4, "explanation has one row per output")
  check(eq(expl.lines[1].expectedQuantity, .5), "explanation exposes expected quantity")
  check(eq(expl.lines[1].grossContrib, .5 * gold), "explanation exposes gross contribution")
  check(eq(expl.lines[1].netContrib, .475 * gold), "explanation exposes net contribution")
  check(eq(expl.expectedNet20, snap.expectedNet20), "explanation exposes expected net")
  check(eq(expl.expectedProfit, snap.expectedProfit), "explanation exposes expected profit")
  check(eq(expl.expectedROI, snap.expectedROI), "explanation exposes expected ROI")
  check(expl.decisionReason == "BUY", "explanation exposes decision reason")
end

if fails == 0 then
  print(string.format("OK  %d checks", passed))
  os.exit(0)
end
io.stderr:write(string.format("%d failed, %d passed\n", fails, passed))
os.exit(1)
