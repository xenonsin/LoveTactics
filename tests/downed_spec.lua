-- Incapacitation & revival (the FFT-style downed countdown). Covers the pieces that are genuinely new
-- over the pre-existing corpse/reanimate system:
--   * a felled REVIVABLE unit lands INCAPACITATED, not yet a corpse: it carries the visible countdown
--     (status_downed) and can be revived, but the necromancer's shelf cannot read it yet;
--   * the countdown running out TURNS THE BODY TO A CORPSE (revivable no more, harvestable now), from
--     onExpire;
--   * a revive inside the window succeeds and cancels the countdown (the body never goes cold);
--   * a revive on a body gone cold is refused;
--   * Reviving Salts brings an incapacitated ally back at a sliver of health, through Combat.useItem;
--   * a won battle still carries even a gone-cold member out (reviveFallenParty);
--   * a NON-revivable body (a demon) skips the whole window: a corpse at once, and no revive takes it.
-- Pure model logic, so it runs headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

-- The Necromancer's severing kit denies the downed window: a KILL from it routes a revivable body
-- straight to a corpse (no status_downed, no revive) instead of laying it down incapacitated. Both the
-- weapon and the ability share the one hook (opts.denyRevival -> Combat.killUnit), so both are exercised
-- through the same helper: a caster with the item and mana to spare, firing at a low-health foe.
local function severKills(itemId)
    local c = Combat.new(Fixture.new(6, 6),
        { Fixture.unit("character_mage", 2, 2, { isolate = "mechanics",
            items = { itemId }, stats = { mana = 100 } }) },
        { Fixture.unit("character_bandit", 4, 2, { isolate = "mechanics",
            stats = { health = 4, magicDefense = 0 } }) })
    local caster, foe = c.units[1], c.units[2]
    assert(foe.char.revivable, "precondition: the foe is an ordinary, revivable body")
    local ok = Fixture.strike(c, caster, foe, itemId)
    assert(ok, itemId .. " fires at the foe's tile")
    return c, foe
end

local function arena(cols, rows) return Fixture.new(cols, rows) end

-- A unit isolated to "mechanics" by default (traits / bound relics stripped) so a blueprint's innate
-- can't perturb the death path these cases are about.
local function unit(id, x, y, opts)
    opts = opts or {}
    opts.isolate = opts.isolate or "mechanics"
    return Fixture.unit(id, x, y, opts)
end

local function kill(c, u) Combat.dealFlatDamage(c, u, 9999, {}, "test") end

return {
    {
        name = "revivable default: an ordinary character is revivable, a demon is not",
        fn = function()
            assert(Character.instantiate("character_rowan").revivable == true,
                "an ordinary character is revivable by default")
            assert(Character.instantiate("character_demon_grunt").revivable == false,
                "a demon blueprint opts out with revivable = false")
        end,
    },
    {
        name = "a felled revivable unit lands incapacitated (not a corpse) carrying the countdown",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) },
                { unit("character_bandit", 4, 4) })
            local hero = c.units[1]
            kill(c, hero)
            assert(not hero.alive and hero.incapacitated, "a felled real unit lands incapacitated")
            assert(not hero.corpse, "and is NOT yet a corpse (the necromancer can't read it)")
            assert(Combat.corpseAt(c, 2, 2) == nil, "corpseAt refuses an incapacitated body")
            assert(Combat.downedAt(c, 2, 2) == hero, "but downedAt finds it for a revive")
            local st = Status.get(hero, "status_downed")
            assert(st, "the body carries the downed countdown")
            assert(st.remaining == 15, "the countdown starts at the status duration (15 ticks), got "
                .. tostring(st and st.remaining))
        end,
    },
    {
        name = "the countdown running out turns the body to a corpse (harvestable, status gone)",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) },
                { unit("character_bandit", 4, 4) })
            local hero = c.units[1]
            kill(c, hero)
            Status.tick(c, 15) -- age the whole window away
            assert(hero.corpse and not hero.incapacitated, "the window closed: the body went cold to a corpse")
            assert(Combat.corpseAt(c, 2, 2) == hero, "and NOW the necromancer's shelf can read it")
            assert(Combat.downedAt(c, 2, 2) == nil, "no longer a revive target")
            assert(not Status.get(hero, "status_downed"), "and the countdown status is gone")
        end,
    },
    {
        name = "a revive inside the window succeeds and cancels the countdown",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) },
                { unit("character_bandit", 4, 4) })
            local hero = c.units[1]
            kill(c, hero)
            Status.tick(c, 5) -- part of the window elapses
            assert(Status.get(hero, "status_downed").remaining == 10, "the count ticked down")
            assert(Combat.reanimate(c, hero, 0.5), "revive within the window succeeds")
            assert(hero.alive and not hero.corpse and not hero.incapacitated, "back on their feet, no lingering flags")
            assert(not Status.get(hero, "status_downed"), "the revive clears the countdown")
        end,
    },
    {
        name = "a revive on a body gone cold is refused",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) },
                { unit("character_bandit", 4, 4) })
            local hero = c.units[1]
            kill(c, hero)
            Status.tick(c, 15)
            assert(hero.corpse and not hero.incapacitated, "precondition: the window has closed to a corpse")
            assert(Combat.reanimate(c, hero, 0.5) == false, "a cold corpse refuses revival")
            assert(not hero.alive, "and stays down")
        end,
    },
    {
        name = "Reviving Salts bring an incapacitated ally back at 25% through Combat.useItem",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unit("character_rowan", 2, 2, { items = { "consumable_reviving_salts" } }),
                  unit("character_rowan", 3, 2, { isolate = "bare", stats = { health = 100 } }) },
                { unit("character_bandit", 5, 5) })
            local reviver, faller = c.units[1], c.units[2]
            kill(c, faller)
            assert(faller.incapacitated and Status.get(faller, "status_downed"), "the ally is incapacitated")

            local ok = Fixture.strike(c, reviver, faller, "consumable_reviving_salts")
            assert(ok, "the salts are spent on the body's tile")
            assert(faller.alive and not faller.incapacitated, "the ally is up again")
            assert(faller.char.stats.health.current == 25,
                "revived at 25% of a 100 max, got " .. tostring(faller.char.stats.health.current))
        end,
    },
    {
        name = "a won battle carries even a gone-cold member out (reviveFallenParty)",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2, { stats = { health = 100 } }) },
                { unit("character_bandit", 5, 5) })
            local hero = c.units[1]
            kill(c, hero)
            Status.tick(c, 15)
            assert(hero.corpse and not hero.incapacitated, "precondition: the member went cold during the fight")
            Combat.reviveFallenParty(c)
            assert(hero.alive and not hero.corpse, "victory still carries a gone-cold member out")
        end,
    },
    {
        name = "a won battle carries a still-incapacitated member out too (reviveFallenParty)",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2, { stats = { health = 100 } }) },
                { unit("character_bandit", 5, 5) })
            local hero = c.units[1]
            kill(c, hero)
            assert(hero.incapacitated, "precondition: the member fell but the window is still open")
            Combat.reviveFallenParty(c)
            assert(hero.alive and not hero.incapacitated, "victory carries an incapacitated member out")
        end,
    },
    {
        -- NO MODE LOSES A BODY TO A FIGHT IT WON, and this pins it in the mode most likely to want to.
        --
        -- The descent briefly did: a member whose downed count ran out was left on the floor and gone
        -- from the roster. It is reverted, and deliberately. Losing a quarter of the company to one bad
        -- turn in a fight you WON is the harshest possible reading of a countdown, and it made the
        -- countdown the whole game rather than a beat in it. What carries the stake instead is the
        -- WOUND (models/wound.lua) -- a reserve on the body plus debuffs that stack -- which degrades a
        -- company over an expedition rather than deleting part of it in a turn. The only thing that
        -- ever costs a body is a wipe, and even then they lie where they fell to be fetched.
        name = "a won fight carries out both fallen states, gone cold or not, in every mode",
        fn = function()
            local c = Combat.new(arena(6, 6), {
                unit("character_rowan", 2, 2, { stats = { health = 100 } }),
                unit("character_knight", 3, 3, { stats = { health = 100 } }),
            }, { unit("character_bandit", 5, 5) })
            local cold, warm = c.units[1], c.units[2]
            kill(c, cold)
            Status.tick(c, 15)
            kill(c, warm)
            assert(cold.corpse and not cold.incapacitated, "precondition: one went cold")
            assert(warm.incapacitated, "precondition: the other is still inside the window")

            local carried = Combat.reviveFallenParty(c)
            assert(#carried == 2, "both are carried out, not one")
            assert(cold.alive and warm.alive, "and both are standing")
            assert(not cold.corpse and not warm.incapacitated, "with the fallen flags cleared")
        end,
    },
    {
        name = "a demon skips the whole window: a corpse at once, and no revive takes it",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) },
                { unit("character_demon_grunt", 4, 4) })
            local demon = c.units[2]
            assert(demon.char.revivable == false, "precondition: a demon is not revivable")
            kill(c, demon)
            assert(demon.corpse and not demon.incapacitated, "a demon is a harvestable corpse at once")
            assert(not Status.get(demon, "status_downed"),
                "with no downed countdown -- it can never be saved")
            assert(Combat.reanimate(c, demon, 0.5) == false, "and no revive takes it")
        end,
    },
    {
        name = "The Unreturning: its killing bolt denies the window -- a corpse at once, no revive",
        fn = function()
            local c, foe = severKills("weapon_the_unreturning")
            assert(not foe.alive, "the bolt fell the foe")
            assert(foe.corpse and not foe.incapacitated,
                "a REVIVABLE body it killed is a corpse at once, never incapacitated")
            assert(not Status.get(foe, "status_downed"),
                "with no downed countdown -- there was never a window to reach")
            assert(Combat.corpseAt(c, 4, 2) == foe, "and the necromancer's shelf can read it NOW")
            assert(Combat.reanimate(c, foe, 0.5) == false, "and no revive takes it")
        end,
    },
    {
        name = "Sever the Thread: its killing bolt denies the window the same way",
        fn = function()
            local c, foe = severKills("ability_sever_the_thread")
            assert(not foe.alive, "the bolt fell the foe")
            assert(foe.corpse and not foe.incapacitated, "a corpse at once, never incapacitated")
            assert(not Status.get(foe, "status_downed"), "no downed countdown")
            assert(Combat.reanimate(c, foe, 0.5) == false, "and no revive takes it")
        end,
    },
    {
        name = "Quietus: an assassin's dagger-kill denies the window too (and bleeds a survivor)",
        fn = function()
            -- Melee (range 1), physical, stamina: a rogue standing beside a low-health foe.
            local c = Combat.new(Fixture.new(6, 6),
                { Fixture.unit("character_bandit", 2, 2, { isolate = "mechanics",
                    items = { "weapon_quietus" }, stats = { stamina = 100 } }) },
                { Fixture.unit("character_bandit", 3, 2, { isolate = "mechanics",
                    stats = { health = 4, defense = 0 } }) })
            local caster, foe = c.units[1], c.units[2]
            assert(foe.char.revivable, "precondition: the foe is an ordinary, revivable body")
            assert(Fixture.strike(c, caster, foe, "weapon_quietus"), "the dagger strikes the adjacent foe")
            assert(not foe.alive, "the stab fell the foe")
            assert(foe.corpse and not foe.incapacitated,
                "a REVIVABLE body it killed is a corpse at once, never incapacitated")
            assert(not Status.get(foe, "status_downed"), "with no downed countdown to reach")
            assert(Combat.reanimate(c, foe, 0.5) == false, "and no revive takes it")
        end,
    },
    {
        name = "the severing kit is final only on the KILL -- a mere wound leaves the window intact",
        fn = function()
            -- Same bolt into a HEALTHY body: it wounds without felling, so denyRevival never fires and
            -- the foe stays a normal revivable target for whatever kills it later.
            local c = Combat.new(Fixture.new(6, 6),
                { Fixture.unit("character_mage", 2, 2, { isolate = "mechanics",
                    items = { "weapon_the_unreturning" }, stats = { mana = 100 } }) },
                { Fixture.unit("character_bandit", 4, 2, { isolate = "mechanics",
                    stats = { health = 500, magicDefense = 0 } }) })
            local caster, foe = c.units[1], c.units[2]
            assert(Fixture.strike(c, caster, foe, "weapon_the_unreturning"), "the bolt lands")
            assert(foe.alive, "precondition: it wounded but did not fell")
            assert(not foe.noRevive, "a wound stamps nothing -- only a kill severs the window")
            Combat.dealFlatDamage(c, foe, 9999, {}, "test") -- felled by something else
            assert(foe.incapacitated and Status.get(foe, "status_downed"),
                "so this later death opens the ordinary downed window")
        end,
    },
}
