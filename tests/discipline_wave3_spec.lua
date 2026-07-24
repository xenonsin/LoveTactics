-- S4, field crafting, and the three shelves built on it: Herbalist, Artificer, and the Warbrewer's still.
--
-- The system claim worth pinning hardest is the one that keeps it from being an economy: what you brew
-- in the field is REAL for the fight -- it stacks, it casts, it can be stolen -- and is stripped on the
-- way out (Combat.releaseClaims). A herbalist who could walk home with an armful of free potions would
-- be a business rather than a build.

local Combat = require("models.combat")
local Character = require("models.character")
local Hazard = require("models.hazard")
local Fixture = require("tests.support.fixture")

local function countOf(char, id)
    local n = 0
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then n = n + (it.quantity or 1) end
    end
    return n
end

return {
    -- S4 --------------------------------------------------------------------------------------------
    {
        name = "a field-brewed item is real stock, and does not leave the battlefield",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            local made = Combat.grantItem(combat, h, "consumable_wildcraft_reagent")
            assert(made, "the reagent is brewed")
            assert(made.ephemeral, "and stamped as field stock")
            assert(countOf(h.char, "consumable_wildcraft_reagent") == 1, "it is in the grid, like anything else")

            -- The gate. releaseClaims is what every party member walks out through.
            Combat.releaseClaims(h.char)
            assert(countOf(h.char, "consumable_wildcraft_reagent") == 0,
                "and it does not come home -- field brewing is not an economy")
        end,
    },
    {
        name = "a full grid refuses the brew rather than erroring",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            for i = 1, Character.MAX_INVENTORY do
                h.char.inventory[i] = require("models.item").instantiate("weapon_iron_dagger", 1, 0)
            end
            assert(Combat.grantItem(combat, h, "consumable_wildcraft_reagent") == nil,
                "nine cells is nine cells; the satchel says no")
        end,
    },

    -- HERBALIST -------------------------------------------------------------------------------------
    {
        name = "Distil takes the ground away and puts it in the satchel",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "ability_distil" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            -- Laid by the ENEMY: a herbalist renders down whatever is on the field.
            Hazard.place(combat, 4, 3, "hazard_fire", { side = "enemy" })
            assert(Hazard.at(combat, 4, 3, "hazard_fire"), "there is fire on the ground")

            assert(Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_distil"), "it is distilled")
            assert(countOf(h.char, "consumable_wildcraft_reagent") == 1, "a reagent is in the satchel")
            assert(not Hazard.at(combat, 4, 3, "hazard_fire"),
                "and the fire is out -- the ground is spent, which is what makes it a decision")
        end,
    },
    {
        name = "Distil declines clean ground and keeps the mana",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "ability_distil" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_distil")
            assert(countOf(h.char, "consumable_wildcraft_reagent") == 0,
                "there is nothing on that ground worth having")
        end,
    },
    {
        name = "the Culler's Kit renders down what the herbalist kills, and not what it did not",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_kaya", 3, 3,
                { isolate = "bare", items = { "utility_cullers_kit" } })
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", stats = { defense = 0, health = 1 } })
            local other = Fixture.unit("character_bandit", 8, 8,
                { isolate = "bare", stats = { defense = 0, health = 1 } })
            local combat = Combat.new(map, { hero }, { foe, other })
            local h, f, o = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            -- Killed by somebody else entirely: no reagent.
            Combat.dealFlatDamage(combat, o, 99, { "physical" }, "the floor")
            assert(not o.alive, "the far bandit falls to nothing in particular")
            assert(countOf(h.char, "consumable_wildcraft_reagent") == 0, "and yields nothing")

            assert(Fixture.strike(combat, h, f, h.char.unarmed), "the herbalist fells one itself")
            assert(not f.alive, "it goes down")
            assert(countOf(h.char, "consumable_wildcraft_reagent") == 1, "and that one renders down")
        end,
    },

    -- WARBREWER -------------------------------------------------------------------------------------
    {
        name = "the Field Still brews at the top of the brewer's turn",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_saber", 3, 3,
                { isolate = "bare", items = { "utility_field_still" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.startTurn(combat)
            if Combat.currentUnit(combat) ~= h then return end
            assert(countOf(h.char, "consumable_wildcraft_reagent") >= 1,
                "the still has produced something to drink")
        end,
    },

    -- ARTIFICER -------------------------------------------------------------------------------------
    {
        name = "Field Assembly spends the cheapest thing in the satchel to raise a sentry",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3, { isolate = "bare", items = {
                "ability_field_assembly", "consumable_bitterroot_draught",
            } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            local before = countOf(h.char, "consumable_bitterroot_draught")
            assert(before >= 1, "there is stock to build with")
            assert(Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_field_assembly"), "the sentry is built")
            assert(Combat.unitAt(combat, 4, 3), "and it stands")
            assert(countOf(h.char, "consumable_bitterroot_draught") < before,
                "the draught went into the machine")
        end,
    },
    {
        name = "Field Assembly declines an empty satchel",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3,
                { isolate = "bare", items = { "ability_field_assembly" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_field_assembly")
            assert(not Combat.unitAt(combat, 4, 3), "nothing in the satchel, nothing on the tile")
        end,
    },
    {
        name = "Recall Construct unmakes the artificer's own emplacement and rebuilds it elsewhere",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_mage", 3, 3, { isolate = "bare", items = {
                "ability_recall_construct", "ability_emplace_sentry",
            } })
            local foe = Fixture.unit("character_bandit", 11, 11, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 999, 999

            assert(Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_emplace_sentry"), "a sentry goes up")
            assert(Combat.unitAt(combat, 4, 3), "it stands where it was put")

            h.char.stats.mana.current = 999
            assert(Fixture.strike(combat, h, { x = 5, y = 4 }, "ability_recall_construct"), "it is recalled")
            assert(not Combat.unitAt(combat, 4, 3), "and is no longer where it was")
            assert(Combat.unitAt(combat, 5, 4), "it stands where the artificer wanted it instead")
        end,
    },
    {
        name = "the Salvage Rig makes a destroyed construct worth losing",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_mage", 3, 3, { isolate = "bare", items = {
                "utility_salvage_rig", "ability_emplace_sentry",
            } })
            local foe = Fixture.unit("character_bandit", 5, 3,
                { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 999, 999

            assert(Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_emplace_sentry"), "a sentry goes up")
            local sentry = Combat.unitAt(combat, 4, 3)
            assert(sentry, "beside the bandit")

            local hp = f.char.stats.health.current
            h.char.stats.mana.current = 10
            Combat.dealFlatDamage(combat, sentry, 9999, { "physical" }, "a very large hammer")
            assert(not sentry.alive, "the construct is destroyed")
            assert(f.char.stats.health.current < hp, "and the wreck catches the thing standing next to it")
            assert(h.char.stats.mana.current > 10, "the artificer is paid for the parts")
        end,
    },
}
