-- The Arcanum line's two rules, read the two ways (docs/story.md, "The Arcanum": the mage answers pride
-- with humility). Sublimitas's Perfect Recall answers a spell aimed at her (data/traits/
-- trait_perfect_recall.lua); Gyeom's Diligence banks a little strength from every action and her Ledger
-- releases it only once she has done her best four times over (data/traits/trait_ledger_diligence.lua,
-- data/items/utility/utility_ledger.lua). Headless.

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

return {
    {
        name = "Diligence: every action Gyeom takes lifts her magic a little, and keeps it",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_gyeom"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 3, y = 1 } })
            local gyeom = c.units[1]
            assert(Trait.has(gyeom, "trait_ledger_diligence"), "Gyeom carries her rule")

            -- Her displayed magic starts at the Ledger's suppressed floor (its passive bonus); Diligence
            -- lifts it FROM there, so measure the delta rather than the absolute.
            local function lift() return (gyeom.bonus and gyeom.bonus.magicDamage) or 0 end
            local floor = lift()

            Trait.onCast(c, gyeom, {})
            local step = lift() - floor
            assert(step > 0, "one action banks a little magic above her floor")

            Trait.onCast(c, gyeom, {})
            assert(lift() - floor == step * 2, "and it compounds: a long fight is study, not downtime")
        end,
    },
    {
        name = "the Ledger releases only after she has done her best four times over",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_gyeom"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 4, y = 4 } })
            local gyeom = c.units[1]
            local relic = gyeom.char.inventory[5]
            assert(relic and relic.id == "utility_ledger", "the signature sits in the center cell")

            assert(not Combat.unlockMet(gyeom, relic, c), "locked before she has practised")
            Combat.tally(gyeom, "cast", 1)
            Combat.tally(gyeom, "cast", 1)
            Combat.tally(gyeom, "cast", 1)
            assert(not Combat.unlockMet(gyeom, relic, c), "still locked at three")
            Combat.tally(gyeom, "cast", 1)
            assert(Combat.unlockMet(gyeom, relic, c), "open at the fourth -- the Release")
        end,
    },
    {
        name = "Perfect Recall: a spell aimed at Sublimitas is answered and unravelled; a sword is not",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_general_pride"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_mage"), x = 2, y = 1 } })
            local sublimitas, caster = c.units[1], c.units[2]
            assert(Trait.has(sublimitas, "trait_perfect_recall"), "Sublimitas carries her rule")

            -- A sword is not something she can unweave.
            assert(not Trait.tryCounterMagic(c, sublimitas, caster, { "physical" }),
                "steel passes through: she answers spells, not swings")

            -- A single-target spell aimed at her is unravelled, for mana.
            local manaBefore = Combat.resource(sublimitas.char, "mana")
            assert(Trait.tryCounterMagic(c, sublimitas, caster, { "magical" }),
                "she already knows the spell aimed at her")
            assert(Combat.resource(sublimitas.char, "mana") == manaBefore - 12, "and it cost her mana to answer")
        end,
    },
}
