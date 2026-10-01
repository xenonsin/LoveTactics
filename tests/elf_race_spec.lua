-- Tests for THE ELF RACE (2026-09-30, "Pride's Bestiary", rounds 1-2): Unblemished, the rule every elf of Pride's
-- spire is built on.
--
--   Unblemished   every fight opens with +4 Damage, +4 Magic Damage, +8 Luck and +1 reach; the first blow that
--                 wounds the bearer ends it for the fight, and no heal gives it back
--
-- The bodies that wear it, and their own rules, are pinned in tests/elf_line_spec.lua.

local Combat = require("models.combat")
local Race = require("models.race")
local Item = require("models.item")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

local function board() return Fixture.new(9, 9) end

-- An elf-blooded body on the enemy side and a plain foe beside it.
local function field()
    local elf = unit("character_archer", 4, 4, { isolate = "bare", items = { "utility_elf_blood" }, stats = { health = 100 } })
    local foe = unit("character_archer", 4, 5, { isolate = "bare", stats = { health = 100 } })
    local c = Fixture.combat(board(), foe, { elf })
    local e, f
    for _, u in ipairs(c.units) do if u.side == "enemy" then e = u else f = u end end
    return c, e, f
end

return {
    {
        name = "the elf is a playable humanoid race that hits true, sums its physical resists to zero, and grants Unblemished",
        fn = function()
            local def = Race.defs["elf"]
            assert(def and def.kind == "humanoid", "an elf is a humanoid race")
            assert(def.playable ~= false, "a company may hire an elf (approved)")
            assert(def.bonus.skill == 2, "it hits true")
            local r = def.resist
            assert(r.slash + r.pierce + r.impact == 0, "the physical three sum to zero")
            assert(r.impact < 0, "a club breaks what an edge slides past")
            local grant = Item.defs["utility_elf_blood"]
            assert(grant and grant.bound and grant.noSteal, "Unblemished is an organ, not kit")
        end,
    },
    {
        name = "an elf opens the fight Unblemished, with the lift to damage, magic, luck and reach",
        fn = function()
            local _, elf = field()
            assert(Status.has(elf, "status_unblemished"), "the fight opens with the status on")
            assert(Status.statBonus(elf, "damage") == 4 and Status.statBonus(elf, "magicDamage") == 4,
                "+4 damage and +4 magic damage")
            assert(Status.statBonus(elf, "luck") == 8, "+8 luck")
            assert(Status.statBonus(elf, "range") == 1, "+1 reach, which every ability's range reads")
        end,
    },
    {
        name = "the first wound ends Unblemished",
        fn = function()
            local c, elf, foe = field()
            Combat.dealFlatDamage(c, elf, 5, { "physical" }, "test", foe, { raw = true })
            assert(not Status.has(elf, "status_unblemished"), "the first wound takes it away")
            assert(Status.statBonus(elf, "damage") == 0, "and the elf drops back to normal")
        end,
    },
    {
        name = "no heal restores Unblemished",
        fn = function()
            local c, elf, foe = field()
            Combat.dealFlatDamage(c, elf, 5, { "physical" }, "test", foe, { raw = true })
            Combat.applyHeal(c, elf, 50)
            assert(Fixture.hp(elf) == Combat.unreservedMax(elf.char, "health"), "healed back to full")
            assert(not Status.has(elf, "status_unblemished"), "and still marred: pride does not repent")
        end,
    },
}
