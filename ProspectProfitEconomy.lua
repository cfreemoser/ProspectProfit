ProspectProfit = ProspectProfit or {}
local PP = ProspectProfit
local Eco = {}
PP.Economy = Eco

function Eco.FormatMoney(copper)
  if copper == nil then
    return "—"
  end
  local gold = COPPER_PER_GOLD or 10000
  local silver = COPPER_PER_SILVER or 100
  local neg = copper < 0
  copper = math.floor(math.abs(copper) + 0.5)
  local g = math.floor(copper / gold)
  local s = math.floor((copper % gold) / silver)
  local c = copper % silver
  local text
  if g > 0 then
    text = string.format("%dg %02ds %02dc", g, s, c)
  elseif s > 0 then
    text = string.format("%ds %02dc", s, c)
  else
    text = string.format("%dc", c)
  end
  if neg then
    return "-" .. text
  end
  return text
end

function Eco.FormatAge(stamp)
  if not stamp then
    return "never"
  end
  local ago = math.max(0, time() - stamp)
  if ago < 45 then
    return "just now"
  elseif ago < 3600 then
    return string.format("%dm ago", math.floor(ago / 60 + 0.5))
  elseif ago < 86400 then
    return string.format("%dh ago", math.floor(ago / 3600 + 0.5))
  end
  return string.format("%dd ago", math.floor(ago / 86400 + 0.5))
end

function Eco.StackPrice(snapshot)
  if not snapshot then
    return nil
  end
  if snapshot.oreStack20 and snapshot.oreStack20 > 0 then
    return snapshot.oreStack20
  end
  if snapshot.oreMin and snapshot.oreMin > 0 then
    return snapshot.oreMin * 20
  end
  return nil
end

function Eco.IsListingProfitable(buyout, count, be1)
  if not buyout or buyout <= 0 or not count or count <= 0 or not be1 or be1 <= 0 then
    return false
  end
  return buyout < (be1 * count)
end

function Eco.Compute(ore, prices)
  local ev = 0
  local missing = {}
  for _, gem in ipairs(ore.gems) do
    local p = prices.gems[gem.id]
    if p and p > 0 then
      ev = ev + gem.chance * p
    else
      missing[#missing + 1] = gem.id
    end
  end

  local be1 = ev / 5
  local be20 = be1 * 20
  local stack = prices.oreStack20
  if not stack and prices.oreMin and prices.oreMin > 0 then
    stack = prices.oreMin * 20
  end

  local profit = nil
  if stack then
    profit = be20 - stack
  end

  local rec = "SKIP"
  if profit and profit > 0 then
    rec = "BUY"
  end

  return {
    ev = ev,
    be1 = be1,
    be20 = be20,
    profit = profit,
    rec = rec,
    missing = missing,
    oreMin = prices.oreMin,
    oreStack20 = stack,
  }
end

function Eco.BuildSnapshot(ore, prices)
  local mathResult = Eco.Compute(ore, prices)
  mathResult.lastScan = time()
  mathResult.gems = prices.gems
  return mathResult
end

function Eco.FormatChance(chance)
  local p = (chance or 0) * 100
  if math.abs(p - math.floor(p + 0.5)) < 0.05 then
    return string.format("%d%%", math.floor(p + 0.5))
  end
  return string.format("%.1f%%", p)
end

-- One row per gem: chance × instant-buy price = contribution to one prospect (5 ore).
function Eco.Explain(ore, snap)
  local gems = snap and snap.gems or {}
  local lines = {}
  for _, gem in ipairs(ore.gems) do
    local price = gems[gem.id]
    local priced = price and price > 0
    local contrib = priced and (gem.chance * price) or 0
    lines[#lines + 1] = {
      id = gem.id,
      rare = gem.rare and true or false,
      chance = gem.chance,
      price = priced and price or nil,
      contrib = contrib,
    }
  end
  return {
    lines = lines,
    ev = snap and snap.ev or 0,
    be20 = snap and snap.be20 or 0,
    cost = Eco.StackPrice(snap),
    profit = snap and snap.profit,
    rec = snap and snap.rec or "SKIP",
  }
end
