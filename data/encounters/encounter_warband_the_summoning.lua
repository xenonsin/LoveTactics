-- THE SUMMONING: the six elementals, fought as a company for the first time.
--
-- All six exist and none of them has ever stood on a rolled board -- they are reached only through an
-- alchemist's or a mage's summon. This is the fight where somebody else does the summoning.
--
-- ITS ELEMENT REROLLS, which is what stops it being one fight met eleven times. The type is derived from
-- the day, so the same company is a fire problem on one expedition and a lightning problem on the next --
-- and a party that packed a fire ward finds out which. Deterministic, never random: models/muster.lua
-- rates this composition to colour the overworld marker before the player commits the step, so a
-- composition that rolled dice would price a fight the player then meets as a different one.
--
-- Kept to four ids so the clamp cannot eat the summoner (Arena.SKIRMISH_CAP). The elementals repeat.
local ELEMENTS = {
    "character_fire_elemental",
    "character_ice_elemental",
    "character_lightning_elemental",
    "character_water_elemental",
    "character_earth_elemental",
    "character_wind_elemental",
}

return {
    name = "The Summoning",
    kind = "combat",
    weight = 3,
    minDay = 7,
    composition = function(ctx)
        local day = ctx.day or 1
        local element = ELEMENTS[(day % #ELEMENTS) + 1]
        local list = {
            "character_summoner", -- setup: the bodies, and the onSummonLost retaliation for each
            "character_theurge",  -- payoff: Invocation, amplifying whichever element turned up
            element,
            element,
        }
        for _ = 1, math.floor(day / 17) do list[#list + 1] = element end
        return list
    end,
}
