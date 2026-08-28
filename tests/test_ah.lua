-- Auction result selection and freshness boundaries.
-- Run from repo root: lua tests/test_ah.lua

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

function CreateFrame()
  return {
    RegisterEvent = function() end,
    SetScript = function() end,
  }
end

SlashCmdList = {}
ProspectProfitDB = nil

dofile(root .. "/ProspectProfitData.lua")
dofile(root .. "/ProspectProfitDB.lua")
dofile(root .. "/ProspectProfitEconomy.lua")
dofile(root .. "/ProspectProfitAH.lua")
dofile(root .. "/ProspectProfit.lua")

local PP = ProspectProfit
local AH = PP.AH
local DB = PP.DB
local fails, passed = 0, 0

DB:Init()

local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    fails = fails + 1
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

-- Total stack price does not determine the cheapest per-unit listing.
local minUnit
minUnit = AH.MinPositiveUnit(minUnit, 1000, 1)
minUnit = AH.MinPositiveUnit(minUnit, 5000, 20)
minUnit = AH.MinPositiveUnit(minUnit, 0, 20)
check(minUnit == 250, "minimum positive unit buyout spans unordered rows")

-- Buyout selection must span pages and only consider profitable exact stacks.
local be1 = 100
local best
best = AH.ChooseCheapestBuyout(best, { page = 0, index = 1, buyout = 1500, count = 20 }, be1)
best = AH.ChooseCheapestBuyout(best, { page = 0, index = 2, buyout = 400, count = 5 }, be1)
best = AH.ChooseCheapestBuyout(best, { page = 1, index = 3, buyout = 1900, count = 20 }, be1)
best = AH.ChooseCheapestBuyout(best, { page = 2, index = 4, buyout = 900, count = 20 }, be1)
check(best and best.page == 2 and best.buyout == 900, "cheapest profitable 20-stack wins across pages")

local unprofitable = AH.ChooseCheapestBuyout(nil, { buyout = 2000, count = 20 }, be1)
check(unprofitable == nil, "break-even stack is not selected")

-- Legacy browse results expose 50 rows per page plus a total result count.
check(AH.HasNextPage(0, 50, 120), "page 1 of 3 advances")
check(AH.HasNextPage(1, 50, 120), "page 2 of 3 advances")
check(not AH.HasNextPage(2, 20, 120), "last partial page finishes")
check(not AH.HasNextPage(0, 0, 0), "empty result set finishes")

-- FindBuyout rejects persisted recommendations once the market snapshot expires.
local ore = PP.Data.GetOre(1)
DB:SetSelected(1)
DB:SaveOre(ore.id, { rec = "BUY", be1 = 100, lastScan = now - DB.ORE_TTL })
AH.isOpen = true
local listing, findError
AH:FindBuyout(1, function(found, err)
  listing, findError = found, err
end)
check(listing == nil, "stale buyout search returns no listing")
check(findError == DB.STALE_ORE_ERROR, "stale buyout search asks for another scan")
check(not AH:IsBusy(), "stale buyout search never starts an AH job")

-- The controller rejects stale BUY state before starting an Auction House search.
local originalFindBuyout = AH.FindBuyout
local findCalled = false
local controllerError
AH.FindBuyout = function()
  findCalled = true
end
PP.UI = {
  SetStatus = function(_, message)
    controllerError = message
  end,
}
PP:BuyoutStack()
check(not findCalled, "controller blocks stale recommendation before AH search")
check(controllerError == DB.STALE_ORE_ERROR, "controller surfaces scan-again error")
AH.FindBuyout = originalFindBuyout
PP.UI = nil

-- Confirmation cannot commit a listing tied to an old recommendation.
DB:SaveOre(ore.id, { rec = "BUY", be1 = 100, lastScan = now })
local commitError
AH:CommitBuyout({ itemId = ore.id, count = 20, buyout = 1000, marketScan = now - 1 }, function(_, err)
  commitError = err
end)
check(commitError == DB.STALE_ORE_ERROR, "old confirmation is rejected")
check(not AH:IsBusy(), "old confirmation never starts an AH job")

if fails == 0 then
  print(string.format("OK  %d checks", passed))
  os.exit(0)
end
io.stderr:write(string.format("%d failed, %d passed\n", fails, passed))
os.exit(1)
