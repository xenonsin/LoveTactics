-- The Cathedral line's two rules, read the two ways (docs/story.md, "The other seven": the priest
-- answers lust with devotion). Luxuria's Rapture takes the reserves a foe held back
-- (data/traits/trait_rapture.lua); Amana's Unbidden rule holds nothing back to take and sheds any seizure
-- of her will (data/traits/trait_devotion_unbidden.lua); and her signature opens only once she has given
-- (data/items/utility/utility_reliquary_kept_trust.lua). Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Trait = require("models.trait")
local Status = require("models.status")

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

return {
    {
        name = "Rapture draws off the reserves a foe held back, and takes them into herself",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_general_lust"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_knight"), x = 2, y = 1 } })
            local luxuria, foe = c.units[1], c.units[2]
            assert(Trait.has(luxuria, "trait_rapture"), "Luxuria carries her rule")

            -- Wound her so the reserves she takes have somewhere to go.
            luxuria.char.stats.health.current = 120
            local stamBefore = Combat.resource(foe.char, "stamina")
            local manaBefore = Combat.resource(foe.char, "mana")
            local hpBefore = luxuria.char.stats.health.current
            assert(stamBefore >= 12 and manaBefore >= 12, "the foe has reserves to lose")

            Trait.onCast(c, luxuria, { tx = foe.x, ty = foe.y })

            assert(Combat.resource(foe.char, "stamina") == stamBefore - 12, "12 stamina seized")
            assert(Combat.resource(foe.char, "mana") == manaBefore - 12, "12 mana seized")
            assert(luxuria.char.stats.health.current > hpBefore, "and taken into her as health")
        end,
    },
    {
        name = "Amana holds nothing back: Rapture passes over her, taking nothing",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_general_lust"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_amana"), x = 2, y = 1 } })
            local luxuria, amana = c.units[1], c.units[2]
            assert(Trait.has(amana, "trait_devotion_unbidden"), "Amana carries the Unbidden rule")

            local stamBefore = Combat.resource(amana.char, "stamina")
            local manaBefore = Combat.resource(amana.char, "mana")

            Trait.onCast(c, luxuria, { tx = amana.x, ty = amana.y })

            assert(Combat.resource(amana.char, "stamina") == stamBefore, "her stamina is untouched")
            assert(Combat.resource(amana.char, "mana") == manaBefore, "and her mana too")
        end,
    },
    {
        name = "Amana's will cannot be taken: Charm sheds the instant it lands (a foe's does not)",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_amana"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 2, y = 1 } })
            local amana, bandit = c.units[1], c.units[2]

            Status.apply(c, amana, "status_charm")
            assert(not Status.has(amana, "status_charm"), "Charm slides off Amana")

            -- Control: an ordinary unit with no such rule keeps the status.
            Status.apply(c, bandit, "status_charm")
            assert(Status.has(bandit, "status_charm"), "but it sticks to a unit that can be taken")
        end,
    },
    {
        name = "the Reliquary of the Kept Trust opens only after three mends",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_amana"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 4, y = 4 } })
            local amana = c.units[1]
            local relic = amana.char.inventory[5]
            assert(relic and relic.id == "utility_reliquary_kept_trust", "the signature sits in the center cell")

            assert(not Combat.unlockMet(amana, relic, c), "locked before she has given")
            Combat.tally(amana, "healDone", 1)
            Combat.tally(amana, "healDone", 1)
            assert(not Combat.unlockMet(amana, relic, c), "still locked at two mends")
            Combat.tally(amana, "healDone", 1)
            assert(Combat.unlockMet(amana, relic, c), "open at the third")
        end,
    },
}
