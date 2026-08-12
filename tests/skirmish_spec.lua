-- Tests for the SKIRMISH TIER: an ordinary road fight is small and short, a guardian or an objective
-- is not.
--
-- This is the load-bearing change under the descent. A floor holds ten or twelve stops, which is only
-- playable if the fights between them are two-minute skirmishes rather than six-minute set-pieces --
-- ten set-pieces is an evening, not a level. Everything downstream (floor density, run length, the
-- payout rebase) is sized against that assumption, so it is pinned here rather than trusted.
--
-- The turn-count case at the bottom is the one that matters most, and it is a MEASUREMENT rather than a
-- restatement of the cap: head-count is only a proxy for length, and the thing actually being claimed
-- is that the fight is over quickly. models/autobattle.lua resolves a real fight through the real
-- combat model and reports unit-turns, so the claim is checked against the engine instead of against
-- arithmetic about it.

local Arena = require("models.arena")
local Autobattle = require("models.autobattle")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")
local Muster = require("models.muster")
local Player = require("models.player")

-- Every roadside blueprint that can actually be rolled onto a board, by kind.
local function weightedByKind(kind)
    local out = {}
    for id, def in pairs(Encounter.defs) do
        if def.kind == kind and def.composition then out[#out + 1] = { id = id, def = def } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- How long an ordinary road fight is allowed to run, in the unit-turns models/autobattle.lua counts.
-- MEASURED (see the last case, which drives real fights through the real model): at the skirmish cap
-- these average around twelve, and the budget carries roughly 1.5x headroom over the worst single one.
-- Shared by two cases -- the length itself, and the technique cap that has to be sized against it --
-- because a fight's length is the one number both of those claims are really about.
local SKIRMISH_TURN_BUDGET = 22

local function openedBodies(def, prestige)
    local ctx = { prestige = prestige, encounterKind = def.kind }
    return #Arena.clampComposition(Arena.resolveComposition(def.composition, ctx), Arena.enemyCap(ctx))
end

return {
    { name = "an ordinary road fight opens at the skirmish cap, however deep the run gets", fn = function()
        -- Prestige 200 is well past anything a campaign reaches, on purpose: the compositions grow off
        -- it without bound, so if the ceiling holds here it holds everywhere. This is the case that
        -- would have caught the old behaviour, where a late-run trail fight fielded a dozen bodies.
        for _, e in ipairs(weightedByKind("combat")) do
            for _, prestige in ipairs({ 1, 6, 20, 200 }) do
                local n = openedBodies(e.def, prestige)
                assert(n <= Arena.SKIRMISH_CAP, e.id .. " opens " .. n ..
                    " bodies at prestige " .. prestige .. ", past the skirmish cap of " .. Arena.SKIRMISH_CAP)
            end
        end
    end },

    { name = "an elite is bigger than a skirmish and smaller than a set-piece", fn = function()
        assert(Arena.SKIRMISH_CAP < Arena.ELITE_CAP, "an elite outweighs an ordinary stop")
        assert(Arena.ELITE_CAP <= Arena.ENEMY_CAP.Normal, "and still sits under a real set-piece")
        for _, e in ipairs(weightedByKind("elite")) do
            local n = openedBodies(e.def, 200)
            assert(n <= Arena.ELITE_CAP, e.id .. " opens " .. n .. " bodies, past the elite cap")
        end
    end },

    { name = "a quest objective still fights at the size it was balanced at", fn = function()
        -- The regression guard for the whole campaign. 92 objectives were authored and balanced against
        -- the difficulty caps; the skirmish tier must not reach them. `objective` has no entry in
        -- CAP_BY_KIND, so it falls through -- this pins that fall-through rather than assuming it.
        for label, cap in pairs(Arena.ENEMY_CAP) do
            local ctx = { quest = { difficulty = label }, encounterKind = "objective" }
            assert(Arena.enemyCap(ctx) == cap,
                "a " .. label .. " objective must still cap at " .. cap)
        end
        -- And a fight with no kind at all (a scripted leg, a duel) is unchanged.
        assert(Arena.enemyCap({}) == Arena.DEFAULT_ENEMY_CAP, "an unkinded fight reads as Normal")
    end },

    { name = "the marker prices the fight the player will actually meet", fn = function()
        -- Muster.encounter draws the overworld marker's pips and gates the walk-off offer. If it rated
        -- a nine-body fight the board then fielded as four, every marker on the map would be wrong in
        -- the same direction -- and the walk-off would refuse fights it should have offered.
        local def = Encounter.get("encounter_wolf")
        local ctx = { prestige = 200 }
        local rated = Muster.encounter(def, ctx)

        local Growth = require("models.growth")
        local ids = Arena.clampComposition(
            Arena.resolveComposition(def.composition, { prestige = 200, encounterKind = def.kind }),
            Arena.SKIRMISH_CAP)
        local byHand = 0
        for _, id in ipairs(ids) do
            byHand = byHand + Muster.rate(Growth.spawn(id, Growth.levelForPrestige(200), nil))
        end
        assert(rated == byHand, "the marker's rating is the skirmish's, not the raw composition's")
    end },

    { name = "cutting the bodies did not cut the pay", fn = function()
        -- The regression this stage could most easily have shipped. Gold used to be purely linear in
        -- head-count, so dropping an ordinary fight from nine bodies to four would have paid a bit over
        -- a third of what it used to -- for the same health, the same consumables and the same risk to
        -- the run. models/spoils.lua's flat GOLD_PER_FIGHT term is what answers that, and this is the
        -- case that stops a later tuning pass quietly removing it.
        local Spoils = require("models.spoils")
        local PRESTIGE = 6
        -- The BEFORE, stated explicitly rather than measured against the current formula: gold was
        -- `8 * count * prestige`, purely linear in head-count. Comparing the new formula against itself
        -- would only measure how sub-linear it is, which is not the question -- the question is what a
        -- player's road fight is worth now against what it was worth then.
        local wasNineBody = 8 * 9 * PRESTIGE

        local N = 40 -- the roll carries +/-15% jitter, so compare averages rather than single rolls
        local nowSkirmish, nowNineBody = 0, 0
        for _ = 1, N do
            nowSkirmish = nowSkirmish + Spoils.roll({ count = 4, prestige = PRESTIGE, kind = "combat" }).gold
            nowNineBody = nowNineBody + Spoils.roll({ count = 9, prestige = PRESTIGE, kind = "combat" }).gold
        end
        nowSkirmish, nowNineBody = nowSkirmish / N, nowNineBody / N

        assert(nowSkirmish / wasNineBody > 0.8, "a four-body skirmish now pays " ..
            math.floor(nowSkirmish / wasNineBody * 100) .. "% of what the old nine-body road fight paid" ..
            " -- cutting the head-count must not cut the reward with it")
        assert(nowSkirmish < nowNineBody, "...but a bigger fight is still worth more than a smaller one")
    end },

    { name = "a deeper floor pays better, but on a shallower slope than prestige", fn = function()
        -- BOTH HALVES OF THE DEPTH CURVE, and they pull against each other on purpose.
        --
        -- Up: the landing's extract-or-descend question needs a number behind it, not only nerve.
        -- Down: a floor level CLIMBS inside a single run where prestige is fixed for the whole of one,
        -- so lending prestige's straight multiple to the floor compounds eight times over a long
        -- descent. Measured that way, floor 7 handed over eleven thousand gold against a shelf whose
        -- dearest row is a few hundred. The band below is what keeps one cleared floor worth roughly
        -- one thing off a shelf at every depth rather than only at the top of the run.
        local Spoils = require("models.spoils")
        local shallow, deep, campaign = 0, 0, 0
        local N = 40
        for _ = 1, N do
            shallow = shallow + Spoils.roll({ count = 4, prestige = 1, kind = "combat", floorLevel = 1 }).gold
            deep = deep + Spoils.roll({ count = 4, prestige = 1, kind = "combat", floorLevel = 13 }).gold
            campaign = campaign + Spoils.roll({ count = 4, prestige = 13, kind = "combat" }).gold
        end
        assert(deep > shallow * 2.5, "floor 13 pays " .. math.floor(deep / shallow * 10) / 10 ..
            "x floor 1 -- descending has to be visibly worth more than staying shallow")
        assert(deep < shallow * 6, "floor 13 pays " .. math.floor(deep / shallow * 10) / 10 ..
            "x floor 1 -- past this the deep floors drown the shelf and gold stops being a decision")
        -- And the campaign, which passes no floorLevel, keeps prestige's straight multiple exactly.
        -- The two are deliberately NOT the same number at the same depth: this is the assertion that
        -- says so, so a later pass cannot quietly re-unify them and reintroduce the compounding.
        assert(campaign > deep * 2, "a fixed prestige of 13 must still scale straight -- the campaign " ..
            "was not in scope for this rebase and must come out of it unmoved")
    end },

    { name = "the anti-grind cap is sized against the fight it is capping", fn = function()
        -- Discipline.TECHNIQUE_PER_BATTLE exists to stop a player milking one encounter with `free`
        -- abilities that never end the turn. A cap only does that job while it sits close to what the
        -- fight can honestly produce; far above, it bounds nothing and the milking is simply allowed.
        --
        -- The fight's honest production is bounded by its LENGTH, which the case below pins by
        -- measurement. Both edges are asserted, because the failure is two-sided: too low clips a
        -- committed player mid-fight, too high reopens the door.
        local Discipline = require("models.discipline")
        local cap = Discipline.TECHNIQUE_PER_BATTLE
        local perAction = Discipline.TECHNIQUE_PER_ACTION
        -- The player's side takes roughly half a fight's unit-turns (four fielded against a skirmish
        -- cap of four), so this is what committing every one of them to a single house would bank.
        local honest = (SKIRMISH_TURN_BUDGET / 2) * perAction
        assert(cap >= honest, "the cap (" .. cap .. ") is under what an honestly played skirmish can " ..
            "bank (" .. honest .. ") -- a committed player would be clipped mid-fight")
        assert(cap <= SKIRMISH_TURN_BUDGET * perAction, "the cap (" .. cap .. ") sits past the whole " ..
            "fight's unit-turns spent on one house (" .. SKIRMISH_TURN_BUDGET * perAction .. ") -- " ..
            "above that it bounds nothing, and refusing to finish a skirmish pays better than winning it")
    end },

    { name = "a strong company cannot farm the shallows", fn = function()
        -- Floor 1 pays what floor 1 is worth however decorated the party walking it. The descent
        -- branch reads the floor and never the company, which is the half of the depth curve that
        -- makes descending the only way to earn -- the other half being Muster.WALK_OVER offering to
        -- skip the fight outright.
        local Spoils = require("models.spoils")
        local fresh, veteran = 0, 0
        local N = 40
        for _ = 1, N do
            fresh = fresh + Spoils.roll({ count = 4, prestige = 1, kind = "combat", floorLevel = 1 }).gold
            veteran = veteran + Spoils.roll({ count = 4, prestige = 20, kind = "combat", floorLevel = 1 }).gold
        end
        assert(math.abs(fresh - veteran) / fresh < 0.15,
            "floor 1 paid a prestige-20 company " .. math.floor(veteran / fresh * 100) ..
            "% of what it paid a fresh one -- depth is what pays on a descent, never standing")
    end },

    { name = "an ordinary road fight is over quickly, measured against the real model", fn = function()
        -- The claim this whole stage rests on, checked rather than asserted. Driven through the same
        -- build/deploy/open sequence the walk-off uses (states/game.lua's autoResolve), so it is the
        -- fight the player would have stood in.
        --
        -- The budget is in UNIT-TURNS, which is what the model counts. models/autobattle.lua's own
        -- header puts an ordinary trail fight "inside forty".
        --
        -- MEASURED at prestige 20 -- chosen because that is where the cap actually BITES; the
        -- compositions are small enough at low prestige that both tiers look identical, and a case run
        -- there would have passed while proving nothing. At the set-piece cap these fights average
        -- ~20 unit-turns; at the skirmish cap, **~12**. The budget carries roughly 1.5x headroom over
        -- the worst single fight. It is a guard against an ordinary stop growing back into a
        -- set-piece, not a tuning target to be nudged whenever it fails.
        local BUDGET = SKIRMISH_TURN_BUDGET

        -- A company that has actually reached this depth, not a fresh one. Levelled by BANKING the
        -- experience it would have earned getting here rather than by setting prestige -- prestige no
        -- longer moves anybody's level (models/experience.lua is the only ladder now).
        local Experience = require("models.experience")
        local player = Player.new()
        player.day = 20
        for _, char in ipairs(player.roster) do
            Experience.award(char, Experience.totalFor(11))
        end
        Player.resolveLevels(player)
        local worst, worstId = 0, nil
        for _, e in ipairs(weightedByKind("combat")) do
            -- The encounter is passed in CELL shape -- `{ id, kind }` -- because that is what the
            -- overworld puts on a tile and what EncounterBattle.spec resolves the composition through
            -- (`enc.id` -> the blueprint). Handing it the blueprint table instead looks like it works
            -- and silently builds a one-bandit default fight, which is a measurement of nothing.
            local built = EncounterBattle.build({
                encounter = { id = e.id, kind = e.def.kind },
                biome = "forest", prestige = 20,
                party = player.roster, seed = 20260809,
            })
            -- Guard the harness itself: if the composition ever stops reaching the arena, every number
            -- below becomes meaningless while still passing. This case has already been wrong that way
            -- once.
            assert(#built.arena.enemies > 1,
                e.id .. " built a " .. #built.arena.enemies .. "-body fight -- the composition is not " ..
                "reaching the arena, so this case is measuring nothing")
            EncounterBattle.autoDeploy(built.combat, built.arena, Muster.fielded(player))
            Combat.openBattle(built.combat)
            local _, turns = Autobattle.run(built.combat, { maxTurns = 400 })
            -- An UNDECIDED fight (nil result) still reports its turns; what is being measured is
            -- length, and a fight that cannot resolve is the worst version of the thing being guarded.
            if turns > worst then worst, worstId = turns, e.id end
        end
        assert(worst > 0, "the harness actually ran a fight")
        assert(worst <= BUDGET, "the longest ordinary road fight took " .. worst ..
            " unit-turns (" .. tostring(worstId) .. "), past the skirmish budget of " .. BUDGET ..
            " -- an ordinary stop has grown back into a set-piece")
    end },
}
