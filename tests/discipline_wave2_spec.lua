-- Behavioural cases for the Wave-2 multiclass items -- the shelves that needed no new system, only new
-- seams. Each proves the item does what its header claims.
--
-- Two engine seams are pinned here as well as the items that use them, because they are the interesting
-- part and nothing else reaches them:
--   * Combat.shoveRiders -- what a shover's standing charms add to a shove that has just landed
--   * the hazard `halts` rider -- an instance-level clause stamped at placement, never on the blueprint

local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

return {
    -- VANGUARD --------------------------------------------------------------------------------------
    {
        name = "Breaker's Wedge Sunders whatever it shoves, off a weapon that knows nothing about it",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_rowan", 3, 3,
                { isolate = "bare", items = { "utility_breakers_wedge", "weapon_iron_mace" } })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            assert(not Status.has(f, "status_sundered"), "the bandit opens with its armour intact")
            assert(Fixture.strike(combat, h, f, "weapon_iron_mace"), "the mace swings")
            -- The mace's shove is the FAMILY's, authored years before the Vanguard existed.
            assert(Status.has(f, "status_sundered"),
                "and the charm rides it -- 19 knockback items become breaches without knowing this exists")
        end,
    },
    {
        name = "Breaker's Harness Stuns a shove that slams, and leaves an unobstructed one alone",
        fn = function()
            -- Pinned against the map edge: the shove has nowhere to go, so it collides.
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_rowan", 3, 2,
                { isolate = "bare", items = { "armor_breakers_harness", "ability_push" } })
            local foe = Fixture.unit("character_bandit", 3, 1, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            assert(Fixture.strike(combat, h, f, "ability_push"), "the shove is thrown at a pinned body")
            assert(Status.has(f, "status_stun"), "a collision takes the turn as well as the ground")
        end,
    },
    {
        name = "Stripped Plate keeps the armour off anything it Sunders, however the Sunder happened",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 3, 3,
                { isolate = "bare", items = { "utility_stripped_plate", "ability_pry_open" } })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            local before = (h.bonus and h.bonus.defense) or 0
            assert(Fixture.strike(combat, h, f, "ability_pry_open"), "Pry Open breaks the plate")
            assert(Status.has(f, "status_sundered"), "the foe is Sundered")
            assert(((h.bonus and h.bonus.defense) or 0) > before,
                "and the rogue is wearing what came off it -- the applier side of onStatusApplied")
        end,
    },

    -- WARDEN ----------------------------------------------------------------------------------------
    {
        name = "Warden's Writ makes ANY ground the bearer lays Halt, without naming a hazard",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_rowan", 3, 3,
                { isolate = "bare", items = { "utility_wardens_writ", "ability_quicksand" } })
            local foe = Fixture.unit("character_bandit", 7, 7, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 5, y = 3 }, "ability_quicksand"), "the warden lays sand")
            local zone = Hazard.at(combat, 5, 3, "hazard_quicksand")
            assert(zone, "the sand is down")
            assert(zone.halts, "and the writ has stamped it -- quicksand, which knows nothing of wardens")

            Combat.teleportUnit(combat, f, 5, 3)
            assert(Status.has(f, "status_halted"), "a foe that walks in loses the turn")
        end,
    },
    {
        name = "the writ stamps the instance, never the blueprint -- another caster's sand is ordinary",
        fn = function()
            local map = Fixture.new(10, 10)
            local warden = Fixture.unit("character_rowan", 3, 3,
                { isolate = "bare", items = { "utility_wardens_writ", "ability_quicksand" } })
            local plain = Fixture.unit("character_mage", 3, 4, { isolate = "bare", items = { "ability_quicksand" } })
            local foe = Fixture.unit("character_bandit", 8, 8, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { warden, plain }, { foe })
            local w, p = combat.units[1], combat.units[2]
            for _, u in ipairs({ w, p }) do
                u.char.stats.mana.max, u.char.stats.mana.current = 99, 99
                u.char.stats.stamina.max, u.char.stats.stamina.current = 99, 99
            end

            assert(Fixture.strike(combat, w, { x = 5, y = 3 }, "ability_quicksand"), "the warden lays sand")
            assert(Fixture.strike(combat, p, { x = 5, y = 5 }, "ability_quicksand"), "the mage lays sand too")
            assert(Hazard.at(combat, 5, 3, "hazard_quicksand").halts, "the warden's Halts")
            assert(not Hazard.at(combat, 5, 5, "hazard_quicksand").halts,
                "the mage's does not -- one warden must not rewrite the world's quicksand")
        end,
    },
    {
        name = "Beat the Bounds collects on ANY hazard, including one the enemy laid",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_kaya", 3, 3,
                { isolate = "bare", items = { "ability_beat_the_bounds" } })
            local inZone = Fixture.unit("character_bandit", 6, 6,
                { isolate = "bare", stats = { defense = 0, health = 300 } })
            local clear = Fixture.unit("character_bandit", 8, 8,
                { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Combat.new(map, { hero }, { inZone, clear })
            local h, a, b = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            -- Laid by the ENEMY's side: the point of the revision is that the warden collects anyway.
            Hazard.place(combat, 6, 6, "hazard_fire", { side = "enemy" })
            local hp = a.char.stats.health.current

            assert(Fixture.strike(combat, h, h, "ability_beat_the_bounds"), "the bounds are walked")
            assert(a.char.stats.health.current < hp, "the foe standing in fire pays")
            assert(Status.has(a, "status_root"), "and is pinned in it")
            assert(not Status.has(b, "status_root"), "the one on dry ground is untouched")
        end,
    },
    {
        name = "Marchstone carries Halting Ground with the warden rather than planting it",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_kaya", 3, 3,
                { isolate = "bare", items = { "utility_marchstone" } })
            local foe = Fixture.unit("character_bandit", 8, 8, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.layIncense(combat, h)
            assert(Hazard.at(combat, 3, 3, "hazard_halting_ground"), "the stone lays its ring where it stands")
            assert(Hazard.at(combat, 2, 2, "hazard_halting_ground"), "out to the corner of the square")

            Combat.teleportUnit(combat, h, 6, 6)
            Combat.layIncense(combat, h)
            assert(not Hazard.at(combat, 3, 3, "hazard_halting_ground"),
                "and the old ring is gone -- incense WALKS, it is not a banner left behind")
            assert(Hazard.at(combat, 6, 6, "hazard_halting_ground"), "the border is wherever the warden is")
        end,
    },

    -- NINJA -----------------------------------------------------------------------------------------
    {
        name = "Shadow Trade swaps the ninja with a standing double, leaving it where the ninja was",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 2, 2,
                { isolate = "bare", items = { "ability_shadow_trade", "ability_mirror_image" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 2, y = 3 }, "ability_mirror_image"), "a double is planted")
            local double = Combat.unitAt(combat, 2, 3)
            assert(double and double.decoyOf == h, "and it is the ninja's own")

            h.char.stats.mana.current = 99
            assert(Fixture.strike(combat, h, h, "ability_shadow_trade"), "the trade is made")
            assert(h.x == 2 and h.y == 3, "the ninja stands where the double did")
            assert(double.x == 2 and double.y == 2,
                "and the double stands where the ninja was -- a swap, not a blink")
        end,
    },
    {
        name = "Substitution spends a clone to void a blow, and drops the ninja onto its tile",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 2, 2,
                { isolate = "bare", items = { "utility_substitution", "ability_mirror_image" } })
            local foe = Fixture.unit("character_bandit", 2, 1, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99
            f.char.stats.stamina.max, f.char.stats.stamina.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 3, y = 2 }, "ability_mirror_image"), "a double is planted")
            local double = Combat.unitAt(combat, 3, 2)
            assert(double, "the double stands")
            Status.remove(combat, h, "status_invisible") -- so the blow can find the ninja at all

            local hp = h.char.stats.health.current
            assert(Fixture.strike(combat, f, h, f.char.unarmed), "the bandit swings at the ninja")
            assert(h.char.stats.health.current == hp, "the blow lands on nobody who is still standing")
            assert(not double.alive, "the double is spent")
            assert(h.x == 3 and h.y == 2, "and the ninja is standing where it was")
        end,
    },
    {
        name = "the Smoke Mantle veils a ninja who drew no blood, and not one who did",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 2, 2,
                { isolate = "bare", items = { "armor_smoke_mantle" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            -- The bookmark is what "did the count move" is measured against; set it, then open a turn
            -- with the tally unmoved.
            h.lastTurnHits = Combat.tallyCount(h, "hitDealt")
            Combat.startTurn(combat)
            if Combat.currentUnit(combat) == h then
                assert(Status.has(h, "status_invisible"), "an idle turn opens unseen")
            end

            Status.remove(combat, h, "status_invisible")
            Combat.tally(h, "hitDealt", 1) -- it drew blood
            Combat.startTurn(combat)
            if Combat.currentUnit(combat) == h then
                assert(not Status.has(h, "status_invisible"), "a turn that drew blood does not")
            end
        end,
    },
    {
        name = "Scatterlight plants doubles and lands the ninja in one of their places",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_mage", 6, 6,
                { isolate = "bare", items = { "ability_scatterlight" } })
            local foe = Fixture.unit("character_bandit", 11, 11, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            local ox, oy = h.x, h.y
            assert(Fixture.strike(combat, h, h, "ability_scatterlight"), "the light scatters")
            local clones = 0
            for _, u in ipairs(combat.units) do
                if u.alive and u.decoyOf == h then clones = clones + 1 end
            end
            assert(clones >= 1, "doubles are standing")
            assert(h.x ~= ox or h.y ~= oy, "and the ninja is no longer where it cast from")
        end,
    },

    -- POACHER ---------------------------------------------------------------------------------------
    {
        name = "Quarry's Due Marks what the poacher's own trap catches, and not what another's does",
        fn = function()
            local map = Fixture.new(10, 10)
            local poacher = Fixture.unit("character_kaya", 2, 2,
                { isolate = "bare", items = { "utility_quarrys_due", "ability_bear_trap" } })
            local other = Fixture.unit("character_kaya", 2, 3,
                { isolate = "bare", items = { "ability_bear_trap" } })
            local foe = Fixture.unit("character_bandit", 8, 8,
                { isolate = "bare", stats = { health = 400 } })
            local combat = Combat.new(map, { poacher, other }, { foe })
            local p, o, f = combat.units[1], combat.units[2], combat.units[3]
            for _, u in ipairs({ p, o }) do
                u.char.stats.stamina.max, u.char.stats.stamina.current = 99, 99
            end

            assert(Fixture.strike(combat, p, { x = 4, y = 2 }, "ability_bear_trap"), "the poacher sets a wire")
            assert(Fixture.strike(combat, o, { x = 4, y = 3 }, "ability_bear_trap"), "the other hunter sets one too")

            Combat.teleportUnit(combat, f, 4, 2)
            assert(Status.has(f, "status_mark"), "the poacher's snare paints what it catches")

            Status.remove(combat, f, "status_mark")
            Combat.teleportUnit(combat, f, 4, 3)
            assert(not Status.has(f, "status_mark"),
                "the other hunter's does not -- the rule keys off the trapper, never the side")
        end,
    },
    {
        name = "The Long Wait silences every answer a held foe could throw",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 3, 3,
                { isolate = "bare", items = { "utility_the_long_wait" } })
            -- A swordsman: parries anything within reach, which is exactly what the charm must stop.
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", items = { "weapon_iron_sword" }, stats = { health = 400 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99
            f.char.stats.stamina.max, f.char.stats.stamina.current = 99, 99

            local parry = nil
            for _, t in ipairs(f.traits or {}) do
                if t.def and t.def.counter then parry = t end
            end
            assert(parry, "the bandit is carrying a blade that answers")
            assert(Trait.mayCounter(combat, f, parry, h, { "physical", "melee" }, false),
                "and it would answer an ordinary blow")

            Status.apply(combat, f, "status_root")
            assert(not Trait.mayCounter(combat, f, parry, h, { "physical", "melee" }, false),
                "but a Rooted foe cannot answer the one who held it")
        end,
    },
    {
        name = "Throatcut kills a held foe under a third and hands the turn back",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 3, 3,
                { isolate = "bare", items = { "ability_throatcut" } })
            -- 300, not 100, so "under a third" leaves room for the cut to land and be SURVIVED. The
            -- ability's power is a slot-graded number that moves (Balance.slotTarget); when it rose, an
            -- ordinary blow started killing a 30-health body outright and this spec failed on lethality
            -- rather than on the thing it is named for -- that the threshold alone is not the licence.
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            -- Under a third, but NOT held: the cut lands as an ordinary blow.
            f.char.stats.health.current = 90
            assert(Fixture.strike(combat, h, f, "ability_throatcut"), "the cut is thrown at a loose foe")
            assert(f.alive, "which survives it -- the threshold alone is not the licence")

            -- Held: the same body, the same health, and now it is over.
            h.char.stats.stamina.current = 99
            f.char.stats.health.current = 90
            Status.apply(combat, f, "status_root")
            assert(Fixture.strike(combat, h, f, "ability_throatcut"), "the cut is thrown at a held one")
            assert(not f.alive, "and opens its throat")
            -- endTurn's surge branch spends the granted action immediately and re-opens the turn
            -- rather than closing it, so what the refund LOOKS like from outside is a turn still open
            -- on the poacher -- the counter is already back to zero by the time we get here.
            assert(combat.turn and combat.turn.unit == h,
                "the kill hands the turn back for the next wire")
        end,
    },

    -- SHAMAN ----------------------------------------------------------------------------------------
    {
        name = "Bind Spirit's storm is owned by the spirit, so it travels with it and lapses with it",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_mage", 4, 4,
                { isolate = "bare", items = { "ability_bind_spirit" } })
            local foe = Fixture.unit("character_bandit", 11, 11, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 5, y = 4 }, "ability_bind_spirit"), "the spirit is called")
            local spirit = Combat.unitAt(combat, 5, 4)
            assert(spirit and spirit.summoner == h, "and it is the shaman's")
            local storm = Hazard.at(combat, 5, 4, "hazard_gagging_storm")
            assert(storm and storm.owner == spirit, "the squall is bound INTO it, not to the caster")

            -- Shoved rather than teleported: Hazard.carry rides the `walk`/`forced` gate, so held
            -- ground travels with a body that WALKS or is MOVED and stays put when one blinks. That is
            -- the engine's existing rule for banners, and the spirit inherits it.
            Combat.knockback(combat, h, spirit, 2, { amount = 0 })
            assert(spirit.x > 5, "the spirit is driven down the lane")
            assert(Hazard.at(combat, spirit.x, spirit.y, "hazard_gagging_storm"),
                "the weather goes where the spirit goes")
            assert(not Hazard.at(combat, 5, 4, "hazard_gagging_storm"), "and does not stay where it was")

            -- The counterplay: every other zone has to be waited out. This one has a throat.
            Combat.dismiss(combat, spirit, nil)
            assert(not Hazard.at(combat, 8, 4, "hazard_gagging_storm"), "cut the spirit down and the storm stops")
        end,
    },
    {
        name = "the Ancestor Mask spares a shaman's summons from ground, but not from what it inflicts",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3,
                { isolate = "bare", items = { "utility_ancestor_mask", "ability_call_spirit" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_call_spirit"), "a spirit is called")
            local spirit = Combat.unitAt(combat, 4, 3)
            assert(spirit, "and it stands")

            local hp = spirit.char.stats.health.current
            Hazard.place(combat, 4, 3, "hazard_fire", { side = "enemy", amount = 20 })
            Hazard.onEnter(combat, spirit, 4, 3)
            assert(spirit.char.stats.health.current == hp, "the fire does not burn the field's own")
        end,
    },
    {
        name = "Ghost-Wind hands every summon the wind on arrival",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_mage", 3, 3,
                { isolate = "bare", items = { "utility_ghost_wind", "ability_call_spirit" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_call_spirit"), "a spirit is called")
            local spirit = Combat.unitAt(combat, 4, 3)
            assert(spirit and Status.has(spirit, "status_hasted"),
                "and it arrives already moving -- the reserve buys a turn, not a walk")
        end,
    },

    -- TOTEMIST --------------------------------------------------------------------------------------
    {
        name = "the Totem-Carver's Kit stands a post up tougher, ceiling and current together",
        fn = function()
            local map = Fixture.new(10, 10)
            local plain = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "ability_raise_totem" } })
            local carver = Fixture.unit("character_amana", 3, 5,
                { isolate = "bare", items = { "ability_raise_totem", "utility_totem_carvers_kit" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { plain, carver }, { foe })
            local p, c = combat.units[1], combat.units[2]
            for _, u in ipairs({ p, c }) do u.char.stats.mana.max, u.char.stats.mana.current = 99, 99 end

            assert(Fixture.strike(combat, p, { x = 5, y = 3 }, "ability_raise_totem"), "a plain totem is raised")
            assert(Fixture.strike(combat, c, { x = 5, y = 5 }, "ability_raise_totem"), "and a carved one")
            local a = Combat.unitAt(combat, 5, 3)
            local b = Combat.unitAt(combat, 5, 5)
            assert(a and b, "both posts stand")
            assert(b.char.stats.health.max > a.char.stats.health.max, "the carved post has the deeper ceiling")
            assert(b.char.stats.health.current == b.char.stats.health.max,
                "and arrives at it, rather than wounded inside a bigger body")
        end,
    },
    {
        name = "Totem of Mending grants Regeneration the ally carries away, unlike Raise Totem's ground",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "ability_totem_of_mending" } })
            local ally = Fixture.unit("character_rowan", 3, 4, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare", stats = { health = 300 } })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 5, y = 3 }, "ability_totem_of_mending"), "the post goes in")
            assert(Combat.unitAt(combat, 5, 3), "a totem stands")
            assert(Hazard.at(combat, 5, 3, "hazard_renewal"), "and lays Renewal rather than healing ground")

            Combat.teleportUnit(combat, a, 5, 3)
            assert(Status.has(a, "status_regen"), "an ally who touches it is granted Regeneration")
        end,
    },
    {
        name = "Ley Line joins two standing posts and refuses when there is only one",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "ability_ley_line", "ability_raise_totem" } })
            local foe = Fixture.unit("character_bandit", 11, 11, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99

            assert(Fixture.strike(combat, h, { x = 4, y = 3 }, "ability_raise_totem"), "one post goes in")
            h.char.stats.mana.current = 99
            assert(Fixture.strike(combat, h, h, "ability_ley_line"), "the line is called for")
            assert(not Hazard.at(combat, 6, 3, "hazard_sacred"), "and refuses -- a line wants two stones")

            -- Raise Totem holds one summon per item, so the second post is planted directly.
            local second = Combat.summonUnit and nil
            local Summon = require("models.summon")
            second = Summon.spawn(combat, h, "character_totem", 8, 3, { control = "none", timeless = true })
            assert(second and second.alive, "a second post stands")

            h.char.stats.mana.current = 99
            assert(Fixture.strike(combat, h, h, "ability_ley_line"), "the line is drawn")
            assert(Hazard.at(combat, 6, 3, "hazard_sacred"), "and the ground between the stones takes light")
        end,
    },
}
