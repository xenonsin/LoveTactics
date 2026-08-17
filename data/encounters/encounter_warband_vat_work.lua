-- THE VAT-WORK, and the reference for every warband blueprint after it.
--
-- A warband is a COMBO, not a roster. Three roles, and the fight is the argument between them:
--
--   setup       lands a condition and is individually weak (the poisoner's Envenom -> Poison)
--   payoff      reads that condition and is paid enormously for it (Detonate, doubled in a blast)
--   multiplier  hits nothing; makes the other two arrive sooner or land more often
--
-- The seam is already authored and this is the pair it was written for: ability_detonate reads
-- fx.hasStatus for Burn or Poison, blasts double into everything adjacent, then consumes it -- and its
-- own header says it "rewards a party that has stacked its damage-over-time first". No party in the
-- game had ever done that, because every composition in data/encounters was N copies of one id.
--
-- FOUR DISTINCT BODIES, WHICH IS THE CEILING AND NOT A COINCIDENCE. Arena.SKIRMISH_CAP is 4 for a
-- `combat` stop, and Arena.clampComposition keeps one of every DISTINCT id before any repeated filler --
-- so a four-role warband survives the clamp whole on any ground, and the filler below is what gets
-- trimmed on a thin board. Author the combo first and the crowd last, always.
return {
    name = "The Vat-Work",
    kind = "combat",
    weight = 3,
    minDay = 3, -- Detonate is a real spike; the opening days meet the simpler gangs instead
    composition = function(ctx)
        local day = ctx.day or 1
        -- Order is load-bearing: the clamp keeps these four, in this order, before any filler.
        local list = {
            "character_poisoner",   -- setup: coatings, and the Poison everything else is priced against
            "character_battlemage", -- payoff: Detonate off that Poison
            "character_bombardier", -- multiplier: charges that make standing anywhere a decision
            "character_bandit",     -- the body that walks at you while the other three work
        }
        for _ = 1, math.floor(day / 12) do list[#list + 1] = "character_bandit" end
        return list
    end,
}
