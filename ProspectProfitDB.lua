ProspectProfit = ProspectProfit or {}
local PP = ProspectProfit
local DB = {}
PP.DB = DB

local function defaults()
  return {
    selectedOreIndex = 6,
    frame = { point = "CENTER", x = 0, y = 80 },
    minimap = { angle = 200, hide = false },
    realms = {},
  }
end

function DB:Init()
  ProspectProfitDB = ProspectProfitDB or {}
  local db = ProspectProfitDB
  local seed = defaults()
  for k, v in pairs(seed) do
    if db[k] == nil then
      db[k] = v
    end
  end
  db.frame = db.frame or seed.frame
  db.minimap = db.minimap or seed.minimap
  db.realms = db.realms or {}
  self.sv = db
end

function DB:Key()
  local realm = GetRealmName() or "Unknown"
  local faction = UnitFactionGroup("player") or "Neutral"
  return realm .. "-" .. faction
end

function DB:Realm()
  local key = self:Key()
  self.sv.realms[key] = self.sv.realms[key] or { ores = {}, gems = {} }
  local realm = self.sv.realms[key]
  realm.ores = realm.ores or {}
  realm.gems = realm.gems or {}
  return realm
end

local MARKET_TTL = 300
local GEM_TTL = MARKET_TTL

DB.ORE_TTL = MARKET_TTL
DB.STALE_ORE_ERROR = "Market scan expired - scan again"

function DB:GetFreshGem(itemId)
  local g = self:Realm().gems[itemId]
  if not g or not g.lastScan then
    return nil
  end
  if (time() - g.lastScan) >= GEM_TTL then
    return nil
  end
  -- 0 means "no listing", not a usable price. Skip so the next scan retries.
  if not g.minBuyout or g.minBuyout <= 0 then
    return nil
  end
  return g.minBuyout
end

function DB:SaveGem(itemId, minBuyout)
  minBuyout = minBuyout or 0
  local realm = self:Realm()
  local prev = realm.gems[itemId]
  -- A failed/empty lookup must not wipe a real cached buyout.
  if minBuyout <= 0 and prev and prev.minBuyout and prev.minBuyout > 0 then
    return
  end
  realm.gems[itemId] = {
    minBuyout = minBuyout,
    lastScan = time(),
  }
end

function DB:GemAge(itemId)
  local g = self:Realm().gems[itemId]
  if not g or not g.lastScan then
    return nil
  end
  return time() - g.lastScan
end

function DB:GetSelected()
  local n = #PP.Data.Ores
  local i = tonumber(self.sv.selectedOreIndex) or 6
  if i < 1 or i > n then
    i = 1
  end
  return i
end

function DB:SetSelected(index)
  self.sv.selectedOreIndex = index
end

function DB:GetOre(oreId)
  local bucket = self:Realm().ores[oreId]
  return bucket
end

function DB:OreAge(oreId)
  local snapshot = self:GetOre(oreId)
  if not snapshot or not snapshot.lastScan then
    return nil
  end
  return time() - snapshot.lastScan
end

function DB:IsOreFresh(oreId)
  local age = self:OreAge(oreId)
  return age ~= nil and age >= 0 and age < self.ORE_TTL
end

function DB:GetFreshOre(oreId)
  local snapshot = self:GetOre(oreId)
  if not snapshot then
    return nil, "Scan the market first"
  end
  if not self:IsOreFresh(oreId) then
    return nil, self.STALE_ORE_ERROR
  end
  return snapshot
end

function DB:SaveOre(oreId, snapshot)
  self:Realm().ores[oreId] = snapshot
end

function DB:GetFrame()
  return self.sv.frame
end

function DB:SetFrame(point, x, y)
  self.sv.frame.point = point
  self.sv.frame.x = x
  self.sv.frame.y = y
end

function DB:GetMinimap()
  return self.sv.minimap
end
