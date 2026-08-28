ProspectProfit = ProspectProfit or {}
local PP = ProspectProfit
local Eco = {}
PP.Economy = Eco

Eco.Policy = {
  sellerCut = 0.05,
  minROI = 0.10,
  minProfit = 10000,
}
Eco.PolicyVersion = 2

local function Policy(overrides)
  overrides = overrides or {}
  return {
    sellerCut = overrides.sellerCut or Eco.Policy.sellerCut,
    minROI = overrides.minROI or Eco.Policy.minROI,
    minProfit = overrides.minProfit or Eco.Policy.minProfit,
  }
end

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

function Eco.IsListingProfitable(buyout, count, buyLimit1)
  if not buyout or buyout <= 0 or not count or count <= 0 or not buyLimit1 or buyLimit1 <= 0 then
    return false
  end
  return buyout <= (buyLimit1 * count)
end

function Eco.Compute(ore, prices, policyOverrides)
  local policy = Policy(policyOverrides)
  local outputs = ore.outputs or ore.gems
  local outputPrices = prices.outputs or prices.gems or {}
  local grossEV = 0
  local missing = {}
  for _, output in ipairs(outputs) do
    local p = outputPrices[output.id]
    if p and p > 0 then
      local expectedQuantity = output.expectedQuantity or output.chance or 0
      grossEV = grossEV + expectedQuantity * p
    else
      missing[#missing + 1] = output.id
    end
  end

  local netEV = grossEV * (1 - policy.sellerCut)
  local expectedNet20 = netEV * 4
  local breakEven1 = netEV / 5
  local maxByROI = expectedNet20 / (1 + policy.minROI)
  local maxByProfit = expectedNet20 - policy.minProfit
  local maxBuy20 = math.max(0, math.min(maxByROI, maxByProfit))
  local maxBuy1 = maxBuy20 / 20
  local stack = prices.oreStack20
  if not stack and prices.oreMin and prices.oreMin > 0 then
    stack = prices.oreMin * 20
  end

  local expectedProfit = nil
  local expectedROI = nil
  if stack then
    expectedProfit = expectedNet20 - stack
    if stack > 0 then
      expectedROI = expectedProfit / stack
    end
  end

  local rec = "SKIP"
  local decisionReason = "NO_ORE_PRICE"
  if expectedProfit and expectedProfit < policy.minProfit then
    decisionReason = "MIN_PROFIT"
  elseif expectedROI and expectedROI < policy.minROI then
    decisionReason = "MIN_ROI"
  elseif expectedProfit and expectedROI then
    rec = "BUY"
    decisionReason = "BUY"
  end

  return {
    grossEV = grossEV,
    netEV = netEV,
    expectedNet20 = expectedNet20,
    expectedProfit = expectedProfit,
    expectedROI = expectedROI,
    sellerCut = policy.sellerCut,
    minROI = policy.minROI,
    minProfit = policy.minProfit,
    maxBuy1 = maxBuy1,
    maxBuy20 = maxBuy20,
    breakEven1 = breakEven1,
    breakEven20 = expectedNet20,
    decisionReason = decisionReason,
    -- Compatibility aliases for existing saved snapshots and AH buyout code.
    ev = netEV,
    be1 = maxBuy1,
    be20 = expectedNet20,
    profit = expectedProfit,
    rec = rec,
    missing = missing,
    oreMin = prices.oreMin,
    oreStack20 = stack,
  }
end

function Eco.BuildSnapshot(ore, prices, policyOverrides)
  local mathResult = Eco.Compute(ore, prices, policyOverrides)
  mathResult.policyVersion = Eco.PolicyVersion
  mathResult.lastScan = time()
  mathResult.outputs = prices.outputs or prices.gems
  mathResult.gems = mathResult.outputs
  return mathResult
end

function Eco.FormatQuantity(quantity)
  quantity = quantity or 0
  if math.abs(quantity - math.floor(quantity + 0.5)) < 0.005 then
    return string.format("%.0f", quantity)
  end
  return string.format("%.2f", quantity)
end

function Eco.FormatChance(chance)
  local p = (chance or 0) * 100
  if math.abs(p - math.floor(p + 0.5)) < 0.05 then
    return string.format("%d%%", math.floor(p + 0.5))
  end
  return string.format("%.1f%%", p)
end

-- One row per output: expected quantity × AH price, less seller cut.
function Eco.Explain(ore, snap)
  local prices = snap and (snap.outputs or snap.gems) or {}
  local sellerCut = snap and snap.sellerCut or Eco.Policy.sellerCut
  local lines = {}
  for _, output in ipairs(ore.outputs or ore.gems) do
    local price = prices[output.id]
    local priced = price and price > 0
    local expectedQuantity = output.expectedQuantity or output.chance or 0
    local grossContrib = priced and (expectedQuantity * price) or 0
    local netContrib = grossContrib * (1 - sellerCut)
    lines[#lines + 1] = {
      id = output.id,
      rare = output.rare and true or false,
      expectedQuantity = expectedQuantity,
      chance = output.chance,
      price = priced and price or nil,
      grossContrib = grossContrib,
      netContrib = netContrib,
      contrib = netContrib,
    }
  end
  return {
    lines = lines,
    grossEV = snap and snap.grossEV or 0,
    netEV = snap and (snap.netEV or snap.ev) or 0,
    expectedNet20 = snap and (snap.expectedNet20 or snap.be20) or 0,
    cost = Eco.StackPrice(snap),
    expectedProfit = snap and (snap.expectedProfit or snap.profit),
    expectedROI = snap and snap.expectedROI,
    sellerCut = sellerCut,
    minROI = snap and snap.minROI or Eco.Policy.minROI,
    minProfit = snap and snap.minProfit or Eco.Policy.minProfit,
    decisionReason = snap and snap.decisionReason or "NO_ORE_PRICE",
    ev = snap and (snap.netEV or snap.ev) or 0,
    be20 = snap and (snap.expectedNet20 or snap.be20) or 0,
    profit = snap and (snap.expectedProfit or snap.profit),
    rec = snap and snap.rec or "SKIP",
  }
end
