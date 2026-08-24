-- Unit tests for prospecting EV / BUY-SKIP math.
-- Run from repo root:  lua tests/test_economy.lua

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
  eps = eps or 0.51
  return math.abs(a - b) < eps
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

-- FormatMoney
check(Eco.FormatMoney(nil) == "—", "nil money is em dash")
check(Eco.FormatMoney(0) == "0c", "zero copper")
check(Eco.FormatMoney(50) == "50c", "copper only")
check(Eco.FormatMoney(-50) == "-50c", "negative copper")
check(Eco.FormatMoney(150) == "1s 50c", "silver + copper")
check(Eco.FormatMoney(123456) == "12g 34s 56c", "full gold/silver/copper")
check(Eco.FormatMoney(-123456) == "-12g 34s 56c", "negative gold")
check(Eco.FormatMoney(1.4) == "1c", "rounds 1.4 down")
check(Eco.FormatMoney(1.6) == "2c", "rounds 1.6 up")

-- FormatAge
check(Eco.FormatAge(nil) == "never", "nil age")
check(Eco.FormatAge(time()) == "just now", "just now")
check(Eco.FormatAge(time() - 120) == "2m ago", "minutes")
check(Eco.FormatAge(time() - 7200) == "2h ago", "hours")
check(Eco.FormatAge(time() - 2 * 86400) == "2d ago", "days")

-- StackPrice
check(Eco.StackPrice(nil) == nil, "nil snapshot")
check(Eco.StackPrice({}) == nil, "empty snapshot")
check(Eco.StackPrice({ oreStack20 = 50 * gold }) == 50 * gold, "prefers listed 20-stack")
check(Eco.StackPrice({ oreMin = 2 * gold }) == 40 * gold, "falls back to unit * 20")
check(Eco.StackPrice({ oreStack20 = 50 * gold, oreMin = 1 * gold }) == 50 * gold, "stack wins over unit")
check(Eco.StackPrice({ oreStack20 = 0, oreMin = 3 * gold }) == 60 * gold, "zero stack ignored")

-- IsListingProfitable: instant-buy vs break-even
check(not Eco.IsListingProfitable(nil, 20, 1000), "nil buyout")
check(not Eco.IsListingProfitable(0, 20, 1000), "bid-only (no instant buy)")
check(not Eco.IsListingProfitable(1000, 0, 1000), "zero count")
check(not Eco.IsListingProfitable(1000, 20, 0), "zero break-even")
check(Eco.IsListingProfitable(19999, 20, 1000), "19999 < 20000 is profitable")
check(not Eco.IsListingProfitable(20000, 20, 1000), "equal to break-even is not profit")
check(not Eco.IsListingProfitable(20001, 20, 1000), "over break-even")
check(Eco.IsListingProfitable(999, 1, 1000), "single ore under be1")

-- Copper: Malachite 50%, Tigerseye 50%, Shadowgem 10%
local copper = oreById(2770)
check(copper ~= nil, "copper ore exists")
do
  local prices = {
    gems = { [774] = 100, [818] = 200, [1210] = 1000 },
    oreStack20 = 1000,
  }
  local r = Eco.Compute(copper, prices)
  -- EV = 0.5*100 + 0.5*200 + 0.1*1000 = 50+100+100 = 250
  check(eq(r.ev, 250), "copper EV 250c, got " .. tostring(r.ev))
  check(eq(r.be1, 50), "copper be1 = EV/5 = 50")
  check(eq(r.be20, 1000), "copper be20 = 50*20 = 1000")
  check(r.profit == 0, "exact break-even profit is 0")
  check(r.rec == "SKIP", "zero profit is SKIP")
  check(#r.missing == 0, "no missing copper gems")
end

-- Missing gem prices count as 0 and are reported
do
  local r = Eco.Compute(copper, { gems = { [774] = 100 }, oreStack20 = 1 })
  check(eq(r.ev, 50), "only malachite priced: EV 50")
  check(#r.missing == 2, "tigerseye + shadowgem missing")
end

-- Zero gem price is treated as missing
do
  local r = Eco.Compute(copper, { gems = { [774] = 0, [818] = 200, [1210] = 0 }, oreStack20 = 1 })
  check(eq(r.ev, 100), "zero prices skipped")
  check(#r.missing == 2, "zero-priced gems listed missing")
end

-- oreMin fallback when no 20-stack listing
do
  local r = Eco.Compute(copper, {
    gems = { [774] = 100, [818] = 200, [1210] = 1000 },
    oreMin = 40,
  })
  check(eq(r.oreStack20, 800), "stack from unit * 20")
  check(eq(r.profit, 200), "1000 - 800 = 200")
  check(r.rec == "BUY", "profit > 0 is BUY")
end

-- No ore price at all
do
  local r = Eco.Compute(copper, { gems = { [774] = 100, [818] = 200, [1210] = 1000 } })
  check(r.profit == nil, "no ore price => no profit")
  check(r.rec == "SKIP", "no ore price is SKIP")
end

-- Fel Iron: 6 greens 18% + 6 rares 1.3%
local fel = oreById(23424)
check(fel and #fel.gems == 12, "fel iron has 12 gems")
do
  local prices = { gems = {}, oreStack20 = 70 * gold }
  for _, gem in ipairs(fel.gems) do
    prices.gems[gem.id] = gem.rare and (100 * gold) or (10 * gold)
  end
  local r = Eco.Compute(fel, prices)
  -- 6*0.18*10g + 6*0.013*100g = 10.8g + 7.8g = 18.6g per prospect
  check(eq(r.ev, 18.6 * gold), "fel EV 18.6g got " .. (r.ev / gold) .. "g")
  check(eq(r.be1, 3.72 * gold), "fel be1 3.72g")
  check(eq(r.be20, 74.4 * gold), "fel be20 74.4g")
  check(eq(r.profit, 4.4 * gold), "74.4 - 70 = 4.4g")
  check(r.rec == "BUY", "70g < 74.4g BUY")

  prices.oreStack20 = 74.4 * gold
  local even = Eco.Compute(fel, prices)
  check(even.rec == "SKIP", "price == gem value is SKIP")

  prices.oreStack20 = 80 * gold
  local skip = Eco.Compute(fel, prices)
  check(skip.rec == "SKIP", "80g > 74.4g SKIP")
  check(skip.profit < 0, "loss is negative")
end

-- Adamantite rares are 4% vs Fel Iron 1.3% — same gem prices, higher EV
local ada = oreById(23425)
do
  local prices = { gems = {}, oreStack20 = 100 * gold }
  for _, gem in ipairs(ada.gems) do
    prices.gems[gem.id] = gem.rare and (100 * gold) or (10 * gold)
  end
  local felR = Eco.Compute(fel, prices)
  local adaR = Eco.Compute(ada, prices)
  check(adaR.ev > felR.ev, "adamantite EV > fel iron EV at same gem prices")
  -- 6*0.18*10 + 6*0.04*100 = 10.8 + 24 = 34.8g
  check(eq(adaR.ev, 34.8 * gold), "adamantite EV 34.8g")
end

-- Khorium shares adamantite table
local khorium = oreById(23426)
do
  local prices = { gems = {}, oreStack20 = 10 * gold }
  for _, gem in ipairs(khorium.gems) do
    prices.gems[gem.id] = 1000
  end
  local a = Eco.Compute(ada, prices)
  local k = Eco.Compute(khorium, prices)
  check(eq(a.ev, k.ev), "khorium EV matches adamantite")
end

-- UI stack story: You keep = gems worth - you pay
do
  local prices = {
    gems = { [774] = 200, [818] = 200, [1210] = 0 },
    oreStack20 = 300,
  }
  local r = Eco.Compute(copper, prices)
  -- EV = 0.5*200 + 0.5*200 = 200; be20 = 800; profit = 500
  check(eq(r.be20, 800), "gems-from-20 = be20")
  check(eq(Eco.StackPrice(r), 300), "you pay = stack price")
  check(eq(r.profit, r.be20 - Eco.StackPrice(r)), "you keep = worth - pay")
end

-- BuildSnapshot stamps time and keeps gem map
do
  local snap = Eco.BuildSnapshot(copper, {
    gems = { [774] = 100, [818] = 100, [1210] = 100 },
    oreStack20 = 10,
  })
  check(type(snap.lastScan) == "number", "snapshot has lastScan")
  check(snap.gems[774] == 100, "snapshot keeps gem prices")
end

-- Loot tables
check(#Data.Ores == 8, "8 ores")
local seen = {}
for _, ore in ipairs(Data.Ores) do
  check(Data.Names[ore.id] ~= nil, "named ore " .. ore.id)
  check(not seen[ore.id], "unique ore " .. ore.id)
  seen[ore.id] = true
  for _, gem in ipairs(ore.gems) do
    check(Data.Names[gem.id] ~= nil, "named gem " .. gem.id)
    check(gem.chance > 0 and gem.chance <= 1, "chance in (0,1] for " .. gem.id)
  end
end
check(Data.Ores[6].id == 23424, "slot 6 Fel Iron")
check(Data.Ores[8].id == 23426, "slot 8 Khorium")

local ids = Data.UniqueScanIds(fel)
check(#ids == 13, "fel scan queue is ore + 12 gems")
check(ids[1] == fel.id, "ore is first in scan queue")

-- Explain math
check(Eco.FormatChance(0.18) == "18%", "18% chance")
check(Eco.FormatChance(0.013) == "1.3%", "1.3% chance")
check(Eco.FormatChance(0.50) == "50%", "50% chance")
do
  local expl = Eco.Explain(copper, {
    gems = { [774] = 100, [818] = 200, [1210] = 1000 },
    ev = 250,
    be20 = 1000,
    oreStack20 = 800,
    profit = 200,
    rec = "BUY",
  })
  check(#expl.lines == 3, "copper explain has 3 gems")
  check(eq(expl.lines[1].contrib, 50), "malachite 50% × 100 = 50")
  check(eq(expl.lines[3].contrib, 100), "shadowgem 10% × 1000 = 100")
  check(expl.lines[3].rare == true or expl.lines[3].chance == 0.10, "shadowgem is the rare")
  check(eq(expl.be20, 1000), "explain keeps be20")
  check(eq(expl.cost, 800), "explain cost from stack")
end
do
  local expl = Eco.Explain(copper, { gems = {} })
  check(expl.lines[1].price == nil, "unpriced gem")
  check(expl.lines[1].contrib == 0, "unpriced contrib 0")
end

if fails == 0 then
  print(string.format("OK  %d checks", passed))
  os.exit(0)
end
io.stderr:write(string.format("%d failed, %d passed\n", fails, passed))
os.exit(1)
