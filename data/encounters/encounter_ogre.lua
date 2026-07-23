-- Encounter blueprint. See data/encounters/encounter_boar.lua for the shape.
--
-- The multi-tile showcase: an Ogre (data/characters/character_ogre.lua) stands on a 2x2 block of
-- the board rather than a single cell, so it walls off ground the way its size says it should. It
-- comes with a small escort so the fight is about working around the bulk rather than surrounding it.
return {
    name = "Ogre",
    kind = "combat",
    weight = 2,
    minPrestige = 2,
    composition = function(ctx)
        local list = { "character_ogre" }
        -- One extra escort per two prestige, so the brute is never entirely alone late on.
        local escorts = 1 + math.floor((ctx.prestige or 1) / 2)
        for _ = 1, escorts do list[#list + 1] = "character_bandit" end
        return list
    end,
}
