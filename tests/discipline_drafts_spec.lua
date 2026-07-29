-- Behavioural cases for the items authored onto the discipline shelves that sat below the five-item
-- floor -- Warlord, Thief and Necromancer first, then Druid, Beastmaster and Monk. Each proves the item
-- does the thing its header claims, not just that it loads.
--
-- Also covers CHI (Combat.chi), the shared pool the Monk shelf is built on: it is engine rather than
-- data, and the two monk abilities are meaningless without it.

local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Status = require("models.status")
local Summon = require("models.summon")
local Fixture = require("tests.support.fixture")

return {
    -- WARLORD ---------------------------------------------------------------------------------------
    {
        name = "Muster Banner plants a standard and lays owned Mustered ground around it",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 3, 4, { isolate = "bare", items = { "ability_muster_banner" } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.stamina.current = 99

            assert(Fixture.strike(combat, h, { x = 4, y = 4 }, "ability_muster_banner"),
                "Muster Banner casts on an empty tile")
            local banner = Combat.unitAt(combat, 4, 4)
            assert(banner and banner.alive, "a banner stands on the aimed tile")
            local zone = Hazard.at(combat, 4, 4, "hazard_muster")
            assert(zone, "Mustered ground covers the standard's tile")
            assert(Hazard.at(combat, 3, 3, "hazard_muster"), "and the corner of its 3x3 square")
            assert(zone.owner == banner, "the ground is owned by the banner, so it drops when the standard falls")
            assert(zone.remaining and zone.remaining > 100,
                "the owned zone quotes the forever-duration, not the muster hazard's short walking clock")
        end,
    },
    {
        name = "War Drums Inspires the allies beside the drummer and no one else",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 3, 3, { isolate = "bare", items = { "consumable_war_drums" } })
            local ally = Fixture.unit("character_rowan", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 3, 2, { isolate = "bare" })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a, f = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.stamina.current = 99

            assert(Fixture.strike(combat, h, h, "consumable_war_drums"), "War Drums is struck")
            assert(Status.has(a, "status_inspiration"), "the ally beside the drummer is Inspired")
            assert(Status.has(h, "status_inspiration"), "and the drummer itself")
            assert(not Status.has(f, "status_inspiration"), "but the adjacent foe hears only a drum")
        end,
    },

    -- THIEF -----------------------------------------------------------------------------------------
    {
        name = "Sap drains the target's stamina to fund the thief's own",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_clem", 2, 2, { isolate = "bare", items = { "ability_sap" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 100 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 20 -- headroom so the restore isn't clamped
            f.char.stats.stamina.max, f.char.stats.stamina.current = 30, 30

            local foeStam0, heroStam0, hp0 = f.char.stats.stamina.current, h.char.stats.stamina.current, f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_sap"), "Sap strikes the adjacent foe")
            assert(f.char.stats.health.current < hp0, "Sap deals damage")
            assert(f.char.stats.stamina.current < foeStam0, "and saps stamina out of the foe")
            -- Sap costs 5 stamina to swing but drains 8 back: the thief ends the turn no poorer than it
            -- started, which only holds because the theft more than funds the cast. (>= not ==: ending a
            -- turn ticks a small regen onto every unit, so exact post-cast totals are not the claim.)
            assert(h.char.stats.stamina.current >= heroStam0, "the sapped stamina lands in the thief's reserves, funding the swing")
        end,
    },
    {
        name = "Shakedown wounds the target and lifts an item off them",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_clem", 2, 2, { isolate = "bare", items = { "ability_shakedown" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 100 }, items = { "weapon_iron_dagger" } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.current = 99

            local hp0 = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_shakedown"), "Shakedown strikes the adjacent foe")
            assert(f.char.stats.health.current < hp0, "Shakedown deals damage")
            assert(Fixture.itemNamed(f.char, "weapon_iron_dagger") == nil, "the foe's weapon is stolen off them")
            assert(Fixture.itemNamed(h.char, "weapon_iron_dagger") ~= nil, "and lands in the thief's own grid")
        end,
    },

    -- NECROMANCER -----------------------------------------------------------------------------------
    {
        name = "Corpse Burst consumes bodies in the area and blasts the ground",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_mage", 5, 7, { isolate = "bare", items = { "ability_corpse_burst" } })
            local victim = Fixture.unit("character_bandit", 5, 5, { isolate = "bare" })
            local bystander = Fixture.unit("character_bandit", 5, 4, { isolate = "bare", stats = { defense = 0, health = 100 } })
            local combat = Combat.new(map, { hero }, { victim, bystander })
            local h, v, by = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.mana.current = 99

            Combat.dealFlatDamage(combat, v, 9999, { "physical" }, "a blow")
            -- A felled human is incapacitated first; age its window out so the body is a raisable corpse
            -- before Corpse Burst reads it.
            Status.tick(combat, 15)
            assert(v.corpse, "the victim's body has gone cold to a corpse at (5,5)")

            local hp0 = by.char.stats.health.current
            assert(Fixture.strike(combat, h, { x = 5, y = 5 }, "ability_corpse_burst"), "Corpse Burst casts on the body's tile")
            assert(not v.corpse, "the corpse in the blast was consumed")
            assert(by.char.stats.health.current < hp0, "and the bystander standing in the area was blasted")
        end,
    },
    {
        name = "Charnel Reliquary raises the bearer's Magic Damage for each nearby death",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 4, 4, { isolate = "bare", items = { "utility_charnel_reliquary" } })
            local near = Fixture.unit("character_bandit", 4, 5, { isolate = "bare" })
            local far = Fixture.unit("character_bandit", 10, 10, { isolate = "bare" })
            local combat = Combat.new(map, { hero }, { near, far })
            local h, n, fa = combat.units[1], combat.units[2], combat.units[3]

            local base = (h.bonus and h.bonus.magicDamage) or 0
            Combat.dealFlatDamage(combat, fa, 9999, { "physical" }, "a blow")
            assert(((h.bonus and h.bonus.magicDamage) or 0) == base, "a death far off pays no dividend")
            Combat.dealFlatDamage(combat, n, 9999, { "physical" }, "a blow")
            assert(((h.bonus and h.bonus.magicDamage) or 0) == base + 2, "a body falling within reach raises Magic Damage")
        end,
    },

    -- CHI (the Monk shelf's shared pool) -------------------------------------------------------------
    {
        name = "chi is banked by bare hands only, and caps",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 2, 2, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            assert(Combat.chi(h) == 0, "a monk opens the fight empty")
            assert(Fixture.strike(combat, h, f, h.char.unarmed), "a bare-handed blow lands")
            assert(Combat.chi(h) == 1, "and banks a point of chi")

            -- The same blow struck with steel banks nothing: chi is built by punching and only by it.
            local dagger = Fixture.give(h.char, "weapon_iron_dagger")
            h.char.stats.stamina.current = 99
            assert(Fixture.strike(combat, h, f, dagger), "a dagger blow lands")
            assert(Combat.chi(h) == 1, "a weapon banks no chi")

            Combat.tally(h, "unarmedHit", 50)
            assert(Combat.chi(h) == Combat.CHI_MAX, "the pool tops out at the cap")
        end,
    },
    {
        name = "Asura Strike scales with chi held and empties the pool, overflow included",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 2, 2, { isolate = "bare", items = { "ability_asura_strike" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 500 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            -- Banked past the cap on purpose, so the "all of it, overflow included" claim is tested.
            Combat.tally(h, "unarmedHit", 14)
            assert(Combat.chi(h) == Combat.CHI_MAX, "the monk is holding a full pool")

            local hp0 = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_asura_strike"), "Asura Strike lands")
            -- Base is 6 at level 0; ten chi adds 60 on top, so a full dump is far past the floor.
            assert(hp0 - f.char.stats.health.current > 50, "a full pool hits vastly harder than the base blow")
            assert(Combat.chi(h) == 0, "and the pool is emptied outright, overflow with it")
        end,
    },
    {
        name = "Flurry needs three chi and throws three bare-handed blows",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 2, 2, { isolate = "bare", items = { "ability_flurry" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            -- Empty-handed of chi, the signature is shut (Combat.unlockMet gates the cast).
            assert(not Fixture.strike(combat, h, f, "ability_flurry"), "with no chi banked, Flurry is refused")

            Combat.tally(h, "unarmedHit", 3)
            local punches = Combat.tallyCount(h, "unarmedHit")
            local hp0 = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_flurry"), "with three chi, Flurry fires")
            assert(f.char.stats.health.current < hp0, "and draws blood")
            assert(Combat.tallyCount(h, "unarmedHit") == punches + 3,
                "three bare-handed blows land, so the fist charms scale all three")
        end,
    },

    -- DRUID ------------------------------------------------------------------------------------------
    {
        name = "Wild Shape: Raven wears a bird's body that is still armed at range",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_kaya", 2, 2, { isolate = "bare", items = { "ability_wild_shape_raven" } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            assert(Fixture.strike(combat, h, h, "ability_wild_shape_raven"), "the hunter takes the shape")
            assert(h.char.name == "Raven", "the body is a raven's")
            assert(Status.has(h, "status_wild_shape_raven"), "and the shape is counting down")
            assert(Fixture.itemNamed(h.char, "weapon_flung_quills"), "armed at range, unlike the wolf and the bear")
        end,
    },
    {
        name = "Fan of Feathers rakes a widening cone away from the caster",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_kaya", 2, 4, { isolate = "bare", items = { "ability_fan_of_feathers" } })
            -- Aimed east at (3,4): row 0 is that cell, row 1 spans (4,3)..(4,5). Both foes are caught;
            -- the third stands behind the caster and is not.
            local near = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { defense = 0, health = 100 } })
            local wide = Fixture.unit("character_bandit", 4, 5, { isolate = "bare", stats = { defense = 0, health = 100 } })
            local behind = Fixture.unit("character_bandit", 1, 4, { isolate = "bare", stats = { defense = 0, health = 100 } })
            local combat = Combat.new(map, { hero }, { near, wide, behind })
            local h, n, w, b = combat.units[1], combat.units[2], combat.units[3], combat.units[4]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            local nhp, whp, bhp = n.char.stats.health.current, w.char.stats.health.current, b.char.stats.health.current
            assert(Fixture.strike(combat, h, { x = 3, y = 4 }, "ability_fan_of_feathers"), "the fan opens")
            assert(n.char.stats.health.current < nhp, "the aimed cell is raked")
            assert(w.char.stats.health.current < whp, "and so is the widening row behind it")
            assert(b.char.stats.health.current == bhp, "but nothing behind the caster is touched")
        end,
    },

    -- BEASTMASTER ------------------------------------------------------------------------------------
    {
        name = "Beastlord's Bond mends the bearer's summoned creatures whenever they act",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_kaya", 3, 3,
                { isolate = "bare", items = { "utility_beastlords_bond", "weapon_iron_dagger" } })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { defense = 0, health = 200 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            local wolf = Summon.spawn(combat, h, "character_wolf_grunt", 2, 3, {})
            assert(wolf and wolf.alive and wolf.summoner == h, "the handler has a creature on the field")
            Combat.dealFlatDamage(combat, wolf, 10, { "physical" }, "a scratch")
            local hurt = wolf.char.stats.health.current

            assert(Fixture.strike(combat, h, f, "weapon_iron_dagger"), "the handler acts")
            assert(wolf.char.stats.health.current > hurt, "and the bond mends the creature beside them")
        end,
    },
}
