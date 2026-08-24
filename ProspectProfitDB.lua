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

local GEM_TTL = 300

function DB:GetFreshGem(itemId)
  local g = self:Realm().gems[itemId]
  if not g or not g.lastScan then
    return nil
  end
  if (time() - g.lastScan) >= GEM_TTL then
    return nil
  end
  return g.minBuyout
end

function DB:SaveGem(itemId, minBuyout)
  self:Realm().gems[itemId] = {
    minBuyout = minBuyout or 0,
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
