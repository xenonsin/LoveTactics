-- The Cathedral line's two rules, read the two ways (docs/story.md, "The other seven": the priest
-- answers lust with devotion). Luxuria's Rapture takes the reserves a foe held back
-- (data/traits/trait_rapture.lua); Xin's Unbidden rule holds nothing back to take and sheds any seizure
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
        -- Rapture left Luxuria's kit on review (2026-09-25) for the Saint's Chalice, which is where it is
        -- carried now; the rule and Xin's exception to it are what these two cases hold.
        name = "Rapture draws off the reserves a foe held back, and takes them into the bearer",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_priest"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_rowan"), x = 2, y = 1 } })
            local luxuria, foe = c.units[1], c.units[2]
            luxuria.traits = luxuria.traits or {}
            luxuria.traits[#luxuria.traits + 1] =
                Trait.instantiate("trait_rapture", Item.instantiate("utility_saints_chalice"))
            assert(Trait.has(luxuria, "trait_rapture"), "the Chalice's bearer carries the rule")

            -- Wound her so the reserves she takes have somewhere to go.
            luxuria.char.stats.health.current = 10
            local stamBefore = Combat.resource(foe.char, "stamina")
            local manaBefore = Combat.resource(foe.char, "mana")
            local hpBefore = luxuria.char.stats.health.current
            assert(stamBefore >= 10 and manaBefore >= 10, "the foe has reserves to lose")

            Trait.onCast(c, luxuria, { tx = foe.x, ty = foe.y })

            assert(Combat.resource(foe.char, "stamina") == stamBefore - 10, "10 stamina seized")
            assert(Combat.resource(foe.char, "mana") == manaBefore - 10, "10 mana seized")
            assert(luxuria.char.stats.health.current > hpBefore, "and taken in as health")
        end,
    },
    {
        name = "Xin holds nothing back: Rapture passes over her, taking nothing",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_priest"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_xin"), x = 2, y = 1 } })
            local luxuria, xin = c.units[1], c.units[2]
            luxuria.traits = luxuria.traits or {}
            luxuria.traits[#luxuria.traits + 1] =
                Trait.instantiate("trait_rapture", Item.instantiate("utility_saints_chalice"))
            assert(Trait.has(xin, "trait_devotion_unbidden"), "Xin carries the Unbidden rule")

            local stamBefore = Combat.resource(xin.char, "stamina")
            local manaBefore = Combat.resource(xin.char, "mana")

            Trait.onCast(c, luxuria, { tx = xin.x, ty = xin.y })

            assert(Combat.resource(xin.char, "stamina") == stamBefore, "her stamina is untouched")
            assert(Combat.resource(xin.char, "mana") == manaBefore, "and her mana too")
        end,
    },
    {
        name = "Xin's will cannot be taken: Charm sheds the instant it lands (a foe's does not)",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_xin"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 2, y = 1 } })
            local xin, bandit = c.units[1], c.units[2]

            Status.apply(c, xin, "status_charm")
            assert(not Status.has(xin, "status_charm"), "Charm slides off Xin")

            -- Control: an ordinary unit with no such rule keeps the status.
            Status.apply(c, bandit, "status_charm")
            assert(Status.has(bandit, "status_charm"), "but it sticks to a unit that can be taken")
        end,
    },
    {
        name = "the Reliquary of the Kept Trust opens only after three heals",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_xin"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 4, y = 4 } })
            local xin = c.units[1]
            local relic = xin.char.inventory[5]
            assert(relic and relic.id == "utility_reliquary_kept_trust", "the signature sits in the center cell")

            assert(not Combat.unlockMet(xin, relic, c), "locked before she has given")
            Combat.tally(xin, "healDone", 1)
            Combat.tally(xin, "healDone", 1)
            assert(not Combat.unlockMet(xin, relic, c), "still locked at two heals")
            Combat.tally(xin, "healDone", 1)
            assert(Combat.unlockMet(xin, relic, c), "open at the third")
        end,
    },
}
