-- The Arcanum line's two rules, read the two ways (docs/story.md, "The Arcanum": the mage answers pride
-- with humility). Sublimitas's Counter Magic answers a spell aimed at her (data/traits/
-- trait_counter_magic.lua); Gyeom's Diligence banks a little strength from every action and her Ledger
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
        -- SHE IS A MAGE, PINNED AGAINST THE REFERENCE BODY -- which the delta test above deliberately
        -- cannot do. It measures `step > 0`, and that is true at 2 and true at 200, so it stayed green
        -- through the whole stretch where she shipped at magicDamage 6: the avatar threw HER Fire Bolt for
        -- 6+16 = 22 and she threw it for 6+6+2 = 14, because per-hit magic damage is
        -- `power + MagicDamage - MagicDefense` (models/combat.lua) and nothing asserted where her number
        -- sat relative to anybody at all.
        --
        -- The claim now is the one her class makes: she OUT-THROWS the reference from the turn she joins,
        -- and Diligence carries her further up while a fight runs. Read off the live blueprints, so it
        -- moves when they move.
        name = "Gyeom out-throws the reference body on arrival, and climbs from there",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_gyeom"), x = 1, y = 1 },
                  { char = Character.instantiate("character_avatar"), x = 2, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 5, y = 5 } })
            local gyeom, avatar = c.units[1], c.units[2]

            local function magic(u) return (u.char.stats.magicDamage or 0) + ((u.bonus or {}).magicDamage or 0) end
            local reference = magic(avatar)
            local opening = magic(gyeom)

            assert(opening > reference,
                "the specialist must out-throw the body every number in the game is measured against; "
                .. "a mage the avatar out-casts is the class not working")

            -- Four actions: the Ledger's own unlock count (utility_ledger.lua's `unlock.count`), so the
            -- climb and the payoff are pinned to the same number rather than to a 4 typed twice.
            local relic = gyeom.char.inventory[5]
            for _ = 1, relic.activeAbility.unlock.count do Trait.onCast(c, gyeom, {}) end

            assert(magic(gyeom) > opening,
                "a long fight is study: by the turn she may Release she is above her own opening")
            -- ...and the climb is a BONUS on a competent body, not a second fix for a broken one. Runaway
            -- here is what a `step` raised to carry a low base would look like after the base was fixed.
            assert(magic(gyeom) < opening * 2,
                "the practice tops her up; it does not double her inside one fight")

            -- ...and the ordering that says she is the MAGE. Both of these read their own headers as
            -- bodies that do not kill, so a mage below either of them is the class not working.
            for _, id in ipairs({ "character_xin", "character_ren" }) do
                local support = Character.instantiate(id)
                assert((gyeom.char.stats.magicDamage or 0) > (support.stats.magicDamage or 0),
                    "the mage's base magic outranks " .. id .. ", who does not kill for a living")
            end
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
        name = "Sublimitas answers a spell aimed at her and unravels it; a sword is not",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_general_pride"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_mage"), x = 2, y = 1 } })
            local sublimitas, caster = c.units[1], c.units[2]
            -- Counter Magic, not a Perfect Recall of its own: hers was a second trait identical but for
            -- answering sooner and cheaper, and those two figures now ride on the codex.
            assert(Trait.has(sublimitas, "trait_counter_magic"), "Sublimitas carries her rule")

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
