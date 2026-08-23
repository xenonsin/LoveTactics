-- Behavioural cases for the items authored onto the discipline shelves that sat below the five-item
-- floor -- Warlord, Thief and Necromancer first, then Druid, Beastmaster and Monk. Each proves the item
-- does the thing its header claims, not just that it loads.
--
-- Also covers CHI (Combat.chi), the shared pool the Monk shelf is built on: it is engine rather than
-- data, and the two monk abilities are meaningless without it.

local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Item = require("models.item")
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
        -- Sap used to drain STAMINA, which made it a second Cutpurse Knife -- same class, same range,
        -- same rung, same two lines. What it moves now is the ARM: the victim's Damage comes off
        -- (status_sapped) and the identical figure goes onto the thief (status_stolen_strength). The
        -- claim under test is the LEDGER -- what one side loses the other gains, exactly -- and the cap
        -- that keeps it a transfer rather than a grant.
        name = "Sap moves the target's Damage onto the thief, capped at the arm it robs",
        fn = function()
            local function sap(foeDamage)
                local map = Fixture.new(8, 8)
                local hero = Fixture.unit("character_clem", 2, 2, { isolate = "bare", items = { "ability_sap" } })
                local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare",
                    stats = { defense = 0, health = 500, damage = foeDamage } })
                local combat = Fixture.combat(map, hero, foe)
                local h, f = combat.units[1], combat.units[2]
                h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

                local hp0 = f.char.stats.health.current
                local foeAtk0, heroAtk0 = Combat.flatStat(f, "damage"), Combat.flatStat(h, "damage")
                assert(Fixture.strike(combat, h, f, "ability_sap"), "Sap strikes the adjacent foe")
                assert(f.char.stats.health.current < hp0, "Sap deals damage")
                return { hero = h, foe = f,
                    took = foeAtk0 - Combat.flatStat(f, "damage"),
                    gained = Combat.flatStat(h, "damage") - heroAtk0 }
            end

            -- An unforged Sap is worth 4 of somebody's arm (4 + fx.level), and every point of it lands.
            local strong = sap(20)
            assert(strong.took == 4, "Sap takes 4 Damage off a strong arm, got " .. strong.took)
            assert(strong.gained == strong.took, "and exactly that much lands on the thief, got " .. strong.gained)
            assert(Status.has(strong.foe, "status_sapped"), "the victim carries the badge that says so")
            assert(Status.has(strong.hero, "status_stolen_strength"), "and the thief carries the other half")

            -- A transfer can only move what is there: rob the scribe and the swing is only a swing.
            -- This is the line that makes Sap ask a different question from the Cutpurse Knife's.
            local weak = sap(0)
            assert(weak.took == 0, "a strengthless body yields no Damage, got " .. weak.took)
            assert(weak.gained == 0, "so the thief gains none either -- nothing is created, got " .. weak.gained)

            -- ...and the cap must never become a gate on the APPLY. Combat.abilityOutput's stand-in
            -- target carries no attack stat, so an effect that skipped the statuses when the theft
            -- came up empty would compute 0 here and drop both badges out of the item's own glossary
            -- -- a card describing an ability that does nothing, visible nowhere but the shelf. The
            -- effect applies both unconditionally and lets the magnitude be 0; this is what says so.
            local out = Combat.abilityOutput(nil, Item.instantiate("ability_sap"))
            local named = {}
            for _, st in ipairs(out.statuses) do named[st.id] = true end
            assert(named.status_sapped, "the shelf tooltip names Sapped")
            assert(named.status_stolen_strength, "and Stolen Strength, the half the thief keeps")
        end,
    },
    {
        -- The inverse of Coup de Grace, and the line that keeps it from being a second Pickpocket:
        -- nothing leaves the target's grid. What it takes is paid for in blood and in coin, and both
        -- shrink as the body does.
        name = "Shakedown hits hardest on an untouched foe and fades as one is worn down",
        fn = function()
            local function shake(healthFraction)
                local map = Fixture.new(8, 8)
                local hero = Fixture.unit("character_clem", 2, 2, { isolate = "bare", items = { "ability_shakedown" } })
                local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare",
                    stats = { defense = 0, health = 1000 }, items = { "weapon_iron_dagger" } })
                local combat = Fixture.combat(map, hero, foe)
                local h, f = combat.units[1], combat.units[2]
                h.char.stats.stamina.current = 99
                f.char.stats.health.current = math.floor(1000 * healthFraction)

                local hp0 = f.char.stats.health.current
                assert(Fixture.strike(combat, h, f, "ability_shakedown"), "Shakedown strikes the adjacent foe")
                return hp0 - f.char.stats.health.current, combat.bounty or 0, f, h
            end

            local whole, richPurse, foe, thief = shake(1.0)
            local half = shake(0.5)
            local broken, thinPurse = shake(0.05)

            assert(broken > 0, "it is still a blow at the bottom of the bar")
            assert(whole > half and half > broken, "the haul falls off as the body does, got "
                .. whole .. " / " .. half .. " / " .. broken)
            -- The bonus is the ability's OWN magnitude put through again -- Curve.ramp(10, 22) at forge
            -- 0, so 10 -- and the attack stat rides on top of both ends alike rather than doubling with
            -- them. That is why the gap is the base and not the whole hit.
            assert(whole - broken >= 9, "an untouched foe eats the ability's base damage again, got "
                .. whole .. " vs " .. broken)

            assert(richPurse > thinPurse and thinPurse >= 0,
                "and the coin that falls out follows the same scale, got " .. richPurse .. " vs " .. thinPurse)

            -- The line that made this a redo rather than a repricing: Pickpocket lifts the kit, this
            -- does not touch it.
            assert(Fixture.itemNamed(foe.char, "weapon_iron_dagger") ~= nil, "nothing is lifted -- that is Pickpocket's verb")
            assert(Fixture.itemNamed(thief.char, "weapon_iron_dagger") == nil, "and the thief's own grid is untouched")
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
        name = "Beastlord's Bond heals the bearer's summoned creatures whenever they act",
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
            assert(wolf.char.stats.health.current > hurt, "and the bond heals the creature beside them")
        end,
    },
}
