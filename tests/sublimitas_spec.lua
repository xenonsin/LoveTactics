-- SUBLIMITAS, THE UNEQUALLED: Pride's lieutenant (data/characters/character_sublimitas.lua; moved down from the
-- general's seat 2026-10-01). Pins her rule, ALREADY KNOWN (data/traits/trait_already_known.lua), on a bare
-- board: a spell she has seen is unravelled when aimed at her, one she has not lands in full and is Known after,
-- one cast out of her sight teaches her nothing, and a weapon is never learned. Then the body (an elf, so she
-- opens Unblemished) and her trophy, the Codex Unanswered, which carries the same rule as a Mage's piece.
-- Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, hp = Fixture.unit, Fixture.hp

-- A caster carrying exactly `items`, with a deep pool so a second cast is never refused for mana.
local function caster(x, y, items)
    return unit("character_mage", x, y, { isolate = "bare", items = items, stats = { mana = 400 } })
end

local function find(combat, id)
    for _, u in ipairs(combat.units) do
        if u.char.id == id then return u end
    end
end

-- A second casting of the same spell, on a fresh turn with the first one's cooldown cleared, so the only
-- thing that can stop it is the rule.
local function castAgain(combat, from, at, id)
    Combat.clearCooldowns(from)
    return Fixture.strike(combat, from, at, Fixture.itemNamed(from.char, id))
end

return {
    {
        name = "a spell she has not seen lands in full, and is Known after",
        fn = function()
            local c = Fixture.combat(Fixture.new(8, 8),
                { caster(2, 2, { "ability_fire_bolt" }) },
                { unit("character_sublimitas", 5, 2) })
            local mage, her = c.units[1], find(c, "character_sublimitas")
            assert(Trait.has(her, "trait_already_known"), "her organ carries the rule")
            local bolt = Fixture.itemNamed(mage.char, "ability_fire_bolt")
            assert(not Trait.knowsSpell(her, bolt), "she opens the fight knowing nothing of yours")

            local before = hp(her)
            assert(Fixture.strike(c, mage, her, bolt), "the bolt is cast")
            assert(hp(her) < before, "an unseen spell lands in full")
            assert(Trait.knowsSpell(her, bolt), "...and is Known from then on")
            local st = Status.get(her, "status_already_known")
            assert(st and st.magnitude == 1, "the badge counts what she knows")
            local line = st.def.describe(st)
            assert(line:find(bolt.name, 1, true), "and the tooltip names it: " .. line)
        end,
    },
    {
        name = "a Known spell aimed at her is unravelled and does nothing",
        fn = function()
            local c = Fixture.combat(Fixture.new(8, 8),
                { caster(2, 2, { "ability_fire_bolt" }) },
                { unit("character_sublimitas", 5, 2) })
            local mage, her = c.units[1], find(c, "character_sublimitas")
            assert(Fixture.strike(c, mage, her, "ability_fire_bolt"), "the first bolt is cast")

            local before = hp(her)
            local ok, result = castAgain(c, mage, her, "ability_fire_bolt")
            assert(ok, "the second casting still happens -- the caster paid for it")
            assert(result and result.warded and result.damageDealt == 0, "and it is unravelled")
            assert(hp(her) == before, "nothing lands")
        end,
    },
    {
        name = "she learns from anyone in her sight, and nothing from a caster she cannot see",
        fn = function()
            -- The bolt is cast by a body on her OWN side, at nobody in particular: "by anyone" means anyone.
            local open = Fixture.combat(Fixture.new(9, 5),
                { caster(1, 3, {}) },
                { unit("character_sublimitas", 8, 3), caster(2, 3, { "ability_fire_bolt" }) })
            local her = find(open, "character_sublimitas")
            local friend = open.units[3]
            local bolt = Fixture.itemNamed(friend.char, "ability_fire_bolt")
            Trait.onAnyCast(open, friend, { item = bolt, ability = bolt.activeAbility })
            assert(Trait.knowsSpell(her, bolt), "a spell her own side works in her sight is learned too")

            -- A wall across the whole board between her and the caster.
            local wall = {}
            for y = 1, 5 do
                wall[#wall + 1] = { x = 5, y = y, type = "wall", walkable = false, sightCost = math.huge }
            end
            local shut = Fixture.combat(Fixture.new(9, 5, { tiles = wall }),
                { caster(2, 3, { "ability_fire_bolt" }) },
                { unit("character_sublimitas", 8, 3) })
            local her2, mage = find(shut, "character_sublimitas"), shut.units[1]
            local bolt2 = Fixture.itemNamed(mage.char, "ability_fire_bolt")
            assert(not Combat.unitsSighted(shut, her2, mage), "the wall really does stand between them")
            Trait.onAnyCast(shut, mage, { item = bolt2, ability = bolt2.activeAbility })
            assert(not Trait.knowsSpell(her2, bolt2), "a working she did not see is not hers")
        end,
    },
    {
        name = "a weapon attack is never learned, however often she sees it",
        fn = function()
            local c = Fixture.combat(Fixture.new(8, 8),
                { caster(2, 2, { "weapon_wand" }) },
                { unit("character_sublimitas", 5, 2) })
            local mage, her = c.units[1], find(c, "character_sublimitas")
            local wand = Fixture.itemNamed(mage.char, "weapon_wand")
            assert(not Trait.isSpell(wand), "a wand's bolt is a basic attack, magical or not")

            local before = hp(her)
            assert(Fixture.strike(c, mage, her, wand), "the wand strikes")
            local first = before - hp(her)
            assert(first > 0, "the wand lands")
            assert(not Trait.knowsSpell(her, wand), "and she learns nothing from it")

            local mid = hp(her)
            castAgain(c, mage, her, "weapon_wand")
            assert(hp(her) < mid, "the second blow lands too: steel is never Known")
        end,
    },
    {
        name = "she is an elf archmage who opens Unblemished, sized as a lieutenant",
        fn = function()
            local def = Character.defs["character_sublimitas"]
            assert(def.name == "Sublimitas, the Unequalled", "she keeps her name")
            assert(def.race == "elf" and def.class == "mage", "an elf, and a mage")
            assert(def.boss and def.tier == 3, "a stair's centrepiece, on the elite rung -- not a general's")
            for _, id in ipairs({ "ability_rain", "ability_fire_bolt", "ability_raise_dead",
                                  "ability_doppelganger", "weapon_wand", "utility_already_known" }) do
                local carried = false
                for _, e in ipairs(def.startingItems) do if e == id then carried = true end end
                assert(carried, "her kit carries " .. id)
            end
            local organ = Item.defs["utility_already_known"]
            assert(organ.class == "creature" and organ.bound and organ.noSteal, "her organ is never loot")

            local c = Fixture.combat(Fixture.new(8, 8),
                { caster(2, 2, {}) }, { unit("character_sublimitas", 5, 2) })
            assert(Status.has(find(c, "character_sublimitas"), "status_unblemished"),
                "an elf opens the fight Unblemished")
            assert(not Trait.has(find(c, "character_sublimitas"), "trait_counter_magic"),
                "Already Known replaced her mana-priced counter")
        end,
    },
    {
        name = "the Codex Unanswered is a Mage's trophy that unravels a spell its bearer has seen",
        fn = function()
            local def = Item.defs["utility_codex_unanswered"]
            assert(def.class == "mage" and def.unstocked and not def.price, "a Mage's piece, never for sale")
            -- Unstealable like every stair's piece (tests/sin_drops_spec.lua), but never bound: real kit, not
            -- a creature's organ.
            assert(not def.bound, "real kit, not a creature's organ")
            assert(def.description == "A spell you have already seen cast this fight is unravelled when aimed at you.",
                "the rule reads as approved")
            assert(Character.defs["character_sublimitas"].drops[1] == "utility_codex_unanswered", "she drops it first")

            local c = Fixture.combat(Fixture.new(8, 8),
                { unit("character_knight", 2, 2, { isolate = "bare", items = { "utility_codex_unanswered" },
                                                   stats = { health = 200 } }) },
                { caster(5, 2, { "ability_fire_bolt" }) })
            local bearer, foe = c.units[1], c.units[2]
            assert(Trait.has(bearer, "trait_already_known"), "the book carries her rule")

            local before = hp(bearer)
            assert(Fixture.strike(c, foe, bearer, "ability_fire_bolt"), "the bolt is cast")
            assert(hp(bearer) < before, "the first one lands")
            local mid = hp(bearer)
            local _, result = castAgain(c, foe, bearer, "ability_fire_bolt")
            assert(result and result.warded and hp(bearer) == mid, "the second is unravelled")
        end,
    },
}
