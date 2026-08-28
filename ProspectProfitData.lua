ProspectProfit = ProspectProfit or {}
local PP = ProspectProfit
local Data = {}
PP.Data = Data

-- English fallbacks used until GetItemInfo caches the localized name.
Data.Names = {
  [2770] = "Copper Ore",
  [2771] = "Tin Ore",
  [2772] = "Iron Ore",
  [3858] = "Mithril Ore",
  [10620] = "Thorium Ore",
  [23424] = "Fel Iron Ore",
  [23425] = "Adamantite Ore",
  [774] = "Malachite",
  [818] = "Tigerseye",
  [1210] = "Shadowgem",
  [1206] = "Moss Agate",
  [1705] = "Lesser Moonstone",
  [1529] = "Jade",
  [3864] = "Citrine",
  [7909] = "Aquamarine",
  [7910] = "Star Ruby",
  [12361] = "Blue Sapphire",
  [12364] = "Huge Emerald",
  [12799] = "Large Opal",
  [12800] = "Azerothian Diamond",
  [23077] = "Blood Garnet",
  [23079] = "Deep Peridot",
  [21929] = "Flame Spessarite",
  [23112] = "Golden Draenite",
  [23107] = "Shadow Draenite",
  [23117] = "Azure Moonstone",
  [23436] = "Living Ruby",
  [23437] = "Talasite",
  [23438] = "Star of Elune",
  [23439] = "Noble Topaz",
  [23440] = "Dawnstone",
  [23441] = "Nightseye",
  [24186] = "Copper Powder",
  [24188] = "Tin Powder",
  [24190] = "Iron Powder",
  [24234] = "Mithril Powder",
  [24235] = "Thorium Powder",
  [24242] = "Fel Iron Powder",
  [24243] = "Adamantite Powder",
}

local function O(id, expectedQuantity, rare)
  return {
    id = id,
    expectedQuantity = expectedQuantity,
    -- Kept for compatibility with callers from earlier releases.
    chance = expectedQuantity,
    rare = rare and true or false,
  }
end

local TBC_GREEN = {
  O(23077, 0.18),
  O(23079, 0.18),
  O(21929, 0.18),
  O(23112, 0.18),
  O(23107, 0.18),
  O(23117, 0.18),
}

local function tbcRare(chance)
  return {
    O(23436, chance, true),
    O(23438, chance, true),
    O(23439, chance, true),
    O(23440, chance, true),
    O(23441, chance, true),
    O(23437, chance, true),
  }
end

local function join(...)
  local out = {}
  for i = 1, select("#", ...) do
    local list = select(i, ...)
    for _, row in ipairs(list) do
      out[#out + 1] = row
    end
  end
  return out
end

Data.Ores = {
  {
    id = 2770,
    skill = 20,
    gems = {
      O(774, 0.50),
      O(818, 0.50),
      O(1210, 0.10, true),
      O(24186, 1),
    },
  },
  {
    id = 2771,
    skill = 50,
    gems = {
      O(1705, 0.375),
      O(1206, 0.375),
      O(1210, 0.375),
      O(7909, 0.0333, true),
      O(3864, 0.0333, true),
      O(1529, 0.0333, true),
      O(24188, 1),
    },
  },
  {
    id = 2772,
    skill = 125,
    gems = {
      O(1705, 0.35),
      O(3864, 0.35),
      O(1529, 0.35),
      O(7910, 0.05, true),
      O(7909, 0.05, true),
      O(24190, 1),
    },
  },
  {
    id = 3858,
    skill = 175,
    gems = {
      O(7910, 0.35),
      O(7909, 0.35),
      O(3864, 0.35),
      O(12361, 0.025, true),
      O(12799, 0.025, true),
      O(12800, 0.025, true),
      O(12364, 0.025, true),
      O(24234, 1),
    },
  },
  {
    id = 10620,
    skill = 250,
    gems = {
      O(7910, 0.30),
      O(12364, 0.16),
      O(12800, 0.16),
      O(12361, 0.16),
      O(12799, 0.16),
      O(23077, 0.0166, true),
      O(23079, 0.0166, true),
      O(21929, 0.0166, true),
      O(23112, 0.0166, true),
      O(23107, 0.0166, true),
      O(23117, 0.0166, true),
      O(24235, 1),
    },
  },
  {
    id = 23424,
    skill = 275,
    gems = join(TBC_GREEN, tbcRare(0.013), {
      O(24242, 1),
    }),
  },
  {
    id = 23425,
    skill = 325,
    gems = join(TBC_GREEN, tbcRare(0.04), {
      O(24243, 1),
    }),
  },
}

for _, ore in ipairs(Data.Ores) do
  ore.outputs = ore.gems
end

function Data.GetName(itemId)
  local name = GetItemInfo(itemId)
  if name and name ~= "" then
    return name
  end
  return Data.Names[itemId]
end

function Data.GetIcon(itemId)
  if GetItemIcon then
    local icon = GetItemIcon(itemId)
    if icon then
      return icon
    end
  end
  local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
  return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Data.GetOre(index)
  return Data.Ores[index]
end

function Data.UniqueScanIds(ore)
  local ids, seen = {}, {}
  local function add(id)
    if id and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  add(ore.id)
  for _, output in ipairs(ore.outputs or ore.gems) do
    add(output.id)
  end
  return ids
end

function Data.Prefetch()
  for id in pairs(Data.Names) do
    GetItemInfo(id)
  end
end
