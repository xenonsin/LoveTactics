-- The Crucible line's two rules, read the two ways (docs/story.md, "The Crucible": the alchemist answers
-- envy with kindness). Livia's Covetous Reflection takes the shape of your strongest at the opening bell
-- (data/traits/trait_covetous_reflection.lua); Ren's Aqua Vitae grants a copy of your strongest to your
-- own side, and only once she has given three times (data/items/utility/utility_aqua_vitae.lua). Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Trait = require("models.trait")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function countSide(c, side)
    local n = 0
    for _, u in ipairs(c.units) do if u.alive and u.side == side then n = n + 1 end end
    return n
end

return {
    {
        name = "Covetous Reflection: Livia opens the fight wearing a copy of your strongest",
        fn = function()
            -- A weak bandit and a strong warlord on the party side; she should covet the warlord.
            local c = Combat.new(arena(8, 8),
                { { char = Character.instantiate("character_bandit"), x = 1, y = 1 },
                  { char = Character.instantiate("character_warlord"), x = 2, y = 1 } },
                { { char = Character.instantiate("character_general_envy"), x = 6, y = 6 } })

            local livia
            for _, u in ipairs(c.units) do if Trait.has(u, "trait_covetous_reflection") then livia = u end end
            assert(livia, "Livia carries her rule (off the Glass in her grid)")

            -- onCombatStart already fired in Combat.new: a copy now stands on her side.
            assert(countSide(c, livia.side) >= 2, "a coveted shape joined her at the opening bell")
            local copy
            for _, u in ipairs(c.units) do
                if u.side == livia.side and u ~= livia and u.alive then copy = u end
            end
            assert(copy and copy.summoned, "the shape is a summoned copy")
            assert(copy.char.name == "Warlord" or (copy.char.stats.damage >= livia.char.stats.damage),
                "she took the STRONGEST foe's shape, not the weakest")
            assert(not copy.fragile, "the finished Work, not the puffer's fragile imitation")
        end,
    },
    {
        name = "Aqua Vitae opens only after Ren has given three times",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_ren"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 5, y = 5 } })
            local ren = c.units[1]
            local relic = ren.char.inventory[5]
            assert(relic and relic.id == "utility_aqua_vitae", "the signature sits in the center cell")

            assert(not Combat.unlockMet(ren, relic, c), "locked before she has given")
            Combat.tally(ren, "healDone", 1)
            Combat.tally(ren, "healDone", 1)
            assert(not Combat.unlockMet(ren, relic, c), "still locked at two gifts")
            Combat.tally(ren, "healDone", 1)
            assert(Combat.unlockMet(ren, relic, c), "open at the third -- the gift")
        end,
    },
}
