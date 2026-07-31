-- Tests for INVERTED MENDING: the one rule that turns a heal into a wound, and its two doors.
--
--   * status_interred -- the curse the necromancer lays with ability_early_rites, cleansable like any
--     debuff;
--   * trait_grave_cold -- what the undead simply are, carried on utility_grave_cold in their grid, and
--     not cleansable at all.
--
-- Both are read through Combat.healingInverted at the single funnel every mend in the game runs
-- through (Combat.applyHeal), so the cases below spend most of their effort on the seams that funnel
-- guards: that a blocked heal still beats an inverted one, that the wound can fell, and that the
-- tooltip's dry run tells the same story the live cast does.
--
-- Pure logic, headless.

local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")
local Character = require("models.character")
local Fixture = require("tests.support.fixture")

local hp = Fixture.hp

-- One healthy body on an open board, isolated down to nothing but what a case gives it.
local function loneUnit(id, opts)
    local u = Fixture.unit(id or "character_rowan", 3, 3, opts or { isolate = "bare" })
    local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
    local c = Fixture.combat(Fixture.new(8, 8), { u }, { foe })
    return c, c.units[1]
end

return {
    {
        name = "Interred turns every mend into a wound of exactly the same size",
        fn = function()
            local c, u = loneUnit()
            u.char.stats.health.current = 40

            assert(Combat.applyHeal(c, u, 12) == 12, "an ordinary mend lands")
            assert(hp(u) == 52, "and moves the bar up")

            Status.apply(c, u, "status_interred")
            assert(Combat.applyHeal(c, u, 12) == 0, "an interred body is never MENDED")
            assert(hp(u) == 40, "the mend landed as a wound of the same 12 points")

            -- Cleansable like any debuff: this takes a healer's window away, not a healer.
            Combat.cleanse(c, u)
            assert(Combat.applyHeal(c, u, 10) == 10, "cured, the body takes mending again")
            assert(hp(u) == 50, "and the bar moves up once more")
        end,
    },
    {
        name = "an inverted mend is unmitigated, answered by nobody, and can fell",
        fn = function()
            local c, u = loneUnit()
            u.char.stats.health.current = 9
            Status.apply(c, u, "status_interred")

            Combat.applyHeal(c, u, 30)
            assert(hp(u) == 0, "the whole amount landed -- armour has no say in a toll")
            assert(not u.alive, "and grace poured into a body past mending kills it")
        end,
    },
    {
        name = "a body that cannot be healed at all is refused, not burned",
        fn = function()
            -- The two flags must never compound: an Unclosing Wound is checked first and refuses
            -- outright, so stacking the pair is worth no more than either alone.
            local c, u = loneUnit()
            u.char.stats.health.current = 30
            Status.apply(c, u, "status_unclosing_wound")
            Status.apply(c, u, "status_interred")

            assert(Combat.applyHeal(c, u, 15) == 0, "the wound refuses the mend")
            assert(hp(u) == 30, "and nothing is turned around on a mend that never landed")
        end,
    },
    {
        name = "every mend runs the same funnel -- a potion and a Regeneration tick burn too",
        fn = function()
            -- Neither of these is a cast aimed by anybody: a draught goes through Combat.quaff and a
            -- Regeneration tick through the status's own ctx.heal, and both come out at applyHeal.
            local c, u = loneUnit("character_rowan",
                { isolate = "bare", items = { "consumable_healing_potion" } })
            u.char.stats.health.current = 40
            Status.apply(c, u, "status_interred")

            local drank = Combat.quaff(c, u, Fixture.itemNamed(u.char, "consumable_healing_potion"))
            assert(drank == 0 and hp(u) < 40, "the draught wounds the body that drinks it")

            local before = hp(u)
            Status.apply(c, u, "status_regen")
            Status.tick(c, Status.TICKS_PER_TURN)
            assert(hp(u) < before, "and a blessing ticking on it does the same, quietly")
        end,
    },

    -- ------------------------------------------------------------- the undead half (trait_grave_cold)
    {
        name = "a raised zombie is grave-cold: a heal aimed at it wounds it instead",
        fn = function()
            local c, u = loneUnit("character_zombie", { isolate = "none" })
            Trait.attach(u)
            assert(Trait.has(u, "trait_grave_cold"),
                "the zombie carries Grave-Cold on utility_grave_cold in its grid")

            u.char.stats.health.current = 20
            assert(Combat.applyHeal(c, u, 8) == 0, "the dead are never mended")
            assert(hp(u) == 12, "the mend landed as a wound instead")
        end,
    },
    {
        name = "being dead is not an affliction: a cleanse does not restore the zombie's mending",
        fn = function()
            local c, u = loneUnit("character_zombie", { isolate = "none" })
            Trait.attach(u)
            u.char.stats.health.current = 20

            Combat.cleanse(c, u)
            assert(Combat.applyHeal(c, u, 8) == 0, "a cure cannot cure being a corpse")
            assert(hp(u) == 12, "and the mend still lands as a wound")
        end,
    },
    {
        name = "the Miller's Ghost is grave-cold too -- the rule is about what a thing IS",
        fn = function()
            local ghost = Character.instantiate("character_miller_ghost")
            local found = false
            for _, item in ipairs(Character.eachItem(ghost)) do
                if item.id == "utility_grave_cold" then found = true end
            end
            assert(found, "the ghost carries Grave-Cold like every other dead thing")
        end,
    },

    -- ------------------------------------------------------------------- the preview tells the truth
    {
        name = "a heal previewed on a grave-cold body reads as damage, for the amount it will take",
        fn = function()
            local healer = Fixture.unit("character_priest", 3, 3,
                { isolate = "bare", items = { "ability_heal" } })
            -- Roomy enough to take the whole mend as a wound without flooring at 0, so the previewed
            -- figure and the bar can be compared exactly.
            local zombie = Fixture.unit("character_zombie", 3, 4, { stats = { health = 90 } })
            local c = Fixture.combat(Fixture.new(8, 8), { healer, zombie }, {})
            local caster, dead = c.units[1], c.units[2]
            Trait.attach(dead)

            local pv = Combat.previewAbility(c, caster, Fixture.itemNamed(caster.char, "ability_heal"),
                dead.x, dead.y)
            local e = pv and pv.entries[dead]
            assert(e, "the preview reports the body it is aimed at")
            assert(e.heal == 0, "and promises it no mending at all")
            assert(e.damage > 0, "it previews the mend as the wound it will be")

            -- The dry run must not have moved the bar: it is asked on every hover frame.
            assert(hp(dead) == 90, "a preview never touches the board")

            -- ...and the live cast lands exactly what was previewed.
            local previewed = e.damage
            Fixture.strike(c, caster, dead, "ability_heal")
            assert(hp(dead) == 90 - previewed,
                "the number the hover promised is the number the cast delivered")
        end,
    },

    -- ---------------------------------------------------------------------------- the spell that says it
    {
        name = "Early Rites lays Interred on one foe, and does no damage doing it",
        fn = function()
            local mage = Fixture.unit("character_mage", 3, 3,
                { isolate = "bare", items = { "ability_early_rites" }, stats = { mana = 60 } })
            local foe = Fixture.unit("character_bandit", 3, 5, { isolate = "bare", stats = { health = 60 } })
            local c = Fixture.combat(Fixture.new(8, 8), { mage }, { foe })
            local caster, target = c.units[1], c.units[2]

            assert(Fixture.strike(c, caster, target, "ability_early_rites"), "the rites are read")
            assert(Status.has(target, "status_interred"), "and the body is counted among the dead")
            assert(hp(target) == 60, "the spell itself does nothing to it -- the healer does that")

            -- The enemy's own priest is now the fastest thing on the board to kill it with.
            target.char.stats.health.current = 30
            Combat.applyHeal(c, target, 20)
            assert(hp(target) == 10, "their mend is the wound")
        end,
    },
}
