-- Gem cache: 0c is "unlisted", not a usable price.
-- Run from repo root:  lua tests/test_db.lua

local here = arg and arg[0] and arg[0]:match("(.+)[/\\]") or "."
local root = here .. "/.."

local now = 1e9
function time()
  return now
end

function GetRealmName()
  return "TestRealm"
end

function UnitFactionGroup()
  return "Horde"
end

ProspectProfitDB = nil

dofile(root .. "/ProspectProfitData.lua")
dofile(root .. "/ProspectProfitDB.lua")
dofile(root .. "/ProspectProfitEconomy.lua")
dofile(root .. "/ProspectProfitAH.lua")

local DB = ProspectProfit.DB
local Data = ProspectProfit.Data
local AH = ProspectProfit.AH

DB:Init()

local fails, passed = 0, 0

local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    fails = fails + 1
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

local ada
for _, ore in ipairs(Data.Ores) do
  if ore.id == 23425 then
    ada = ore
    break
  end
end
check(ada ~= nil and #ada.gems == 13, "adamantite has 12 gems plus powder")

-- Snapshots made under the old gross-value policy must not drive purchases.
DB:SaveOre(ada.id, { rec = "BUY", be1 = 999999 })
check(DB:GetOre(ada.id) == nil, "legacy policy snapshot is invalidated")
local current = { policyVersion = ProspectProfit.Economy.PolicyVersion, rec = "SKIP" }
DB:SaveOre(ada.id, current)
check(DB:GetOre(ada.id) == current, "current policy snapshot is available")
DB.sv.selectedOreIndex = 8
check(DB:GetSelected() == 1, "removed Khorium selection falls back to first ore")
DB.sv.selectedOreIndex = 6

-- Fresh positive buyout is returned
DB:SaveGem(23077, 12345)
check(DB:GetFreshGem(23077) == 12345, "fresh listed gem price")

-- 0c must not count as a cache hit (screenshot: 12 cached + 12 unlisted = 0c)
DB:SaveGem(23079, 0)
check(DB:GetFreshGem(23079) == nil, "zero buyout is not fresh")

-- Empty save is the same as 0
DB:SaveGem(21929, nil)
check(DB:GetFreshGem(21929) == nil, "nil buyout is not fresh")

-- Do not clobber a real price with a later empty lookup
DB:SaveGem(23112, 50000)
DB:SaveGem(23112, 0)
check(DB:GetFreshGem(23112) == 50000, "empty scan keeps last listed price")

-- Expired TTL is not fresh even with a real price
DB:SaveGem(23107, 9000)
now = now + 301
check(DB:GetFreshGem(23107) == nil, "expired gem is not fresh")
now = now - 301

-- Ore recommendations use the same short market TTL.
local oreId = ada.id
DB:SaveOre(oreId, {
  policyVersion = ProspectProfit.Economy.PolicyVersion,
  rec = "BUY",
  be1 = 1000,
  lastScan = now,
})
check(DB:GetFreshOre(oreId) ~= nil, "fresh ore snapshot is actionable")
check(DB:IsOreFresh(oreId), "fresh ore reports fresh")
check(DB:OreAge(oreId) == 0, "fresh ore age is zero")
now = now + DB.ORE_TTL
local expired, expiredError = DB:GetFreshOre(oreId)
check(expired == nil, "expired ore snapshot is rejected")
check(expiredError == DB.STALE_ORE_ERROR, "expired ore asks for another scan")
check(not DB:IsOreFresh(oreId), "expired ore reports stale")
now = now - DB.ORE_TTL

local missingOre, missingError = DB:GetFreshOre(999999)
check(missingOre == nil, "missing ore snapshot is rejected")
check(missingError == "Scan the market first", "missing ore asks for first scan")

DB:SaveOre(oreId, {
  policyVersion = ProspectProfit.Economy.PolicyVersion,
  rec = "BUY",
  be1 = 1000,
  lastScan = now + 1,
})
check(DB:GetFreshOre(oreId) == nil, "future-dated ore snapshot is rejected")

-- BuildScanQueue: 0c gems are live-scanned, listed gems are cached
DB:Realm().gems = {}
local gems = ada.gems
for i, gem in ipairs(gems) do
  DB:SaveGem(gem.id, (i <= 6) and 0 or (10 * 10000))
end
local queue, prices, cached, live = AH:BuildScanQueue(ada, false)
check(cached == 7, "seven listed outputs cached, got " .. tostring(cached))
check(live == 6, "six zero-price outputs live-scanned, got " .. tostring(live))
check(#queue == 1 + 6, "queue is ore + unlisted outputs")
check(queue[1] == ada.id, "ore is first in queue")
for i = 1, 6 do
  check(prices[gems[i].id] == nil, "unlisted gem " .. gems[i].id .. " not in cached prices")
end
for i = 7, 13 do
  check(prices[gems[i].id] == 10 * 10000, "listed gem " .. gems[i].id .. " uses cache")
end

-- Forced scan ignores cache
local q2, p2, c2, l2 = AH:BuildScanQueue(ada, true)
check(c2 == 0 and l2 == 13, "force scan live-queries every output")
check(#q2 == 14, "force queue is ore + 13 outputs")
check(next(p2) == nil, "force scan starts with no gem prices")

if fails == 0 then
  print(string.format("OK  %d checks", passed))
  os.exit(0)
end
io.stderr:write(string.format("%d failed, %d passed\n", fails, passed))
os.exit(1)
