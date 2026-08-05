-- The Undercroft line's two rules (docs/story.md, "The Undercroft": the rogue answers greed with
-- charity). Aurea's Golden Touch lifts the kit out of your hands (data/items/utility/utility_bottomless_purse.lua,
-- fx.steal -- the shipped half of her gold economy); Clem's Borrowed Time turns a kill into the whole
-- party's tempo, and opens only once she has collected three (data/items/weapon/weapon_borrowed_time.lua).
-- Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
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

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

return {
    {
        name = "the Golden Touch lifts an item out of your hands, and the Purse itself cannot be taken back",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { { char = Character.instantiate("character_general_greed"), x = 2, y = 2 } },
                { { char = Character.instantiate("character_rowan"), x = 3, y = 2 } })
            local aurea, victim = c.units[1], c.units[2]

            local purse = itemNamed(aurea.char, "utility_bottomless_purse")
            assert(purse, "Aurea carries her rule in her grid")
            assert(purse.noSteal, "the relic itself can never be lifted off her -- or off you, once you wear it")

            -- Her Golden Touch (Combat.steal, what the Purse's active runs) lifts a real item off a foe.
            local saved = Combat.random
            Combat.random = function() return 1 end
            local stolen = Combat.steal(c, aurea, victim)
            Combat.random = saved
            assert(stolen, "she takes the thing itself -- the clean side of the Greed/Envy line")
            assert(itemNamed(victim.char, stolen.id) == nil, "the victim no longer has it")
        end,
    },
    {
        name = "Borrowed Time is a blade first: it swings on an empty collection, gate-free",
        fn = function()
            -- The rule this pins, and the reason the relic stopped carrying an `unlock`: a weapon always
            -- swings. It was the only gated weapon in the game, which meant Clem opened every fight -- and
            -- every fight AFTER each use, since the gate was repeatable -- holding a blade she could not
            -- use. The three kills buy the jubilee now, never the stroke.
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_clem"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 2, y = 1 } })
            local clem, foe = c.units[1], c.units[2]
            local relic = clem.char.inventory[5]
            assert(relic and relic.id == "weapon_borrowed_time", "the signature sits in the center cell")

            local ab = relic.activeAbility
            assert(not ab.unlock, "no unlock: the gate is a readout, not a purse")
            assert(ab.counter and ab.counterGates == false, "the collection is drawn, and never gates the cast")
            assert(ab.counter(clem, relic) == 0, "and it starts empty")
            assert(Combat.itemBlockReason(clem, relic) == nil, "an empty collection still swings")

            local before = foe.char.stats.health.current
            assert(Combat.useItem(c, clem, relic, 2, 1), "the mercy-stroke lands with nothing collected")
            assert(foe.char.stats.health.current < before, "and it drew blood")
            assert(not Status.has(clem, "status_hasted"), "but nothing was minted -- the jubilee is unearned")
        end,
    },
    {
        name = "three collected kills mint the jubilee, which spends three and keeps the change",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_clem"), x = 1, y = 1 },
                  { char = Character.instantiate("character_rowan"), x = 1, y = 2 } },
                { { char = Character.instantiate("character_bandit"), x = 2, y = 1 } })
            local clem, ally, foe = c.units[1], c.units[2], c.units[3]
            local relic = clem.char.inventory[5]
            -- A punching bag, so the stroke never fells it and muddies the collection it is reading.
            foe.char.stats.health.max, foe.char.stats.health.current = 9999, 9999

            Combat.tally(clem, "kill", 4)
            assert(relic.activeAbility.counter(clem, relic) == 4, "four collected, and the badge says so")

            assert(Combat.useItem(c, clem, relic, 2, 1), "the stroke lands")
            assert(Status.has(clem, "status_hasted"), "she quickens with the party")
            assert(Status.has(ally, "status_hasted"), "and she keeps none of it -- the whole party does")
            assert(relic.activeAbility.counter(clem, relic) == 1,
                "three were spent, not reset: the fourth is change she carries into the next one")
        end,
    },
    {
        name = "the collection is banked through fx, so a hover never spends it",
        fn = function()
            -- Ability effects mutate only through fx.* helpers, because both damage previews REPLAY the
            -- effect against the real tables with an inert bank (models/combat.lua). A raw
            -- `fx.user.mercySpent = ...` would empty her collection under the cursor.
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_clem"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 2, y = 1 } })
            local clem, foe = c.units[1], c.units[2]
            local relic = clem.char.inventory[5]
            Combat.tally(clem, "kill", 3)

            for _ = 1, 5 do
                assert(Combat.previewAbility(c, clem, relic, 2, 1), "the hover prices the stroke")
            end
            assert(relic.activeAbility.counter(clem, relic) == 3, "five hovers spent nothing")
            assert(foe.char.stats.health.current == foe.char.stats.health.max, "and drew no blood")
        end,
    },
}
