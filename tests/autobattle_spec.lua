-- Running a whole fight with nobody watching (models/autobattle.lua), and which fights are allowed to
-- be run that way (models/encounter_battle.lua's eligibility).
--
-- What matters here is that the simulation is a REAL fight and not a coin flip dressed up as one: it
-- reaches a decision, it spends the party's actual resources on the way (that spending is the whole
-- point -- it is what a walked-off fight bills the player), and it stops rather than hanging when it
-- is handed something the combat model alone cannot finish.

local Autobattle = require("models.autobattle")
local EncounterBattle = require("models.encounter_battle")
local Combat = require("models.combat")
local Fixture = require("tests.support.fixture")

-- A fight the party cannot lose: four knights against one wolf, on open ground.
local function lopsided()
    local map = Fixture.new(10, 10)
    local party = {
        Fixture.unit("character_knight", 3, 8), Fixture.unit("character_knight", 4, 8),
        Fixture.unit("character_knight", 5, 8), Fixture.unit("character_knight", 6, 8),
    }
    local foes = { Fixture.unit("character_wolf_grunt", 5, 2) }
    return Fixture.combat(map, party, foes), party, foes
end

return {
    {
        name = "a lopsided fight resolves, and resolves the way it should",
        fn = function()
            local combat = lopsided()
            local result, turns = Autobattle.run(combat)

            assert(result == "win", "four knights beat one wolf; got " .. tostring(result))
            assert(turns > 0, "and it took turns to do it")
            assert(turns < Autobattle.MAX_TURNS, "well inside the guard, got " .. turns)
            assert(Combat.aliveCount(combat, "enemy") == 0, "the wolf is down")
        end,
    },
    {
        name = "the fight is lost when the party is the outmatched side",
        fn = function()
            -- The same loop has to be able to say no. Both sides are AI-driven, so nothing here is
            -- rigged toward the player -- which is exactly why the walk-off gates on muster instead of
            -- trusting the simulation to come out right.
            --
            -- Joined at the start line on purpose: a knight is the `defensive` archetype and so is a
            -- champion, and two lines that both hold their ground never meet (see the standoff case
            -- below). Put them in reach and the fight is a fight.
            local map = Fixture.new(10, 10)
            local party = { Fixture.unit("character_knight", 5, 5, { stats = { health = 6 } }) }
            local foes = {
                Fixture.unit("character_champion", 4, 4), Fixture.unit("character_champion", 5, 4),
                Fixture.unit("character_champion", 6, 4),
            }
            local combat = Fixture.combat(map, party, foes)

            local result = Autobattle.run(combat)
            assert(result == "loss", "one wounded knight against three champions loses; got "
                .. tostring(result))
        end,
    },
    {
        name = "two lines that both hold their ground stand off, and the guard says so",
        fn = function()
            -- Not a contrived case: `defensive` is the knight's whole archetype ("it does not kill
            -- you, it decides where you stand"), so two defensive lines across open ground genuinely
            -- never engage. The loop must report that as UNDECIDED and stop, rather than spinning --
            -- and the walk-off must never take an undecided fight for a victory it watched.
            local map = Fixture.new(10, 10)
            local party = { Fixture.unit("character_knight", 5, 8) }
            local foes = { Fixture.unit("character_champion", 5, 2) }
            local combat = Fixture.combat(map, { party[1] }, foes)

            local result, turns = Autobattle.run(combat, { maxTurns = 40 })
            assert(result == nil, "nobody closed, so nobody won; got " .. tostring(result))
            assert(turns == 40, "and it stopped at the ceiling rather than running on")
            assert(Combat.aliveCount(combat, "party") == 1, "with both lines still standing")
            assert(Combat.aliveCount(combat, "enemy") == 1)
        end,
    },
    {
        name = "the fight is billed to the party's own characters",
        fn = function()
            -- The billing IS the feature. Party chars ride into a battle by reference, so what the
            -- simulation spends comes off the roster the player walks away with -- exactly as a fought
            -- battle does. If this ever stops being true, a walked-off fight becomes free.
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_knight", 5, 7)
            local foes = {
                Fixture.unit("character_bandit", 4, 3), Fixture.unit("character_bandit", 6, 3),
            }
            local combat = Fixture.combat(map, { hero }, foes)
            local before = hero.char.stats.health.current

            Autobattle.run(combat)

            assert(hero.char.stats.health.current < before,
                "two bandits cost the knight health, and the wound lands on the roster's own body")
        end,
    },
    {
        name = "an undecidable fight trips the guard instead of hanging",
        fn = function()
            -- A `survive` objective is scored against a clock states/battle.lua advances, not the
            -- model -- so nothing in this loop can ever end it. It must come back undecided rather
            -- than spinning. (EncounterBattle.eligible refuses such a fight upstream; this is the
            -- backstop behind that gate.)
            local map = Fixture.new(8, 8, { objective = { type = "survive", turns = 999 } })
            local hero = Fixture.unit("character_knight", 4, 6)
            local combat = Fixture.combat(map, { hero }, { Fixture.unit("character_knight", 4, 1) })

            local result, turns = Autobattle.run(combat, { maxTurns = 20 })
            assert(result == nil, "undecided is nil, not a draw and not a win")
            assert(turns == 20, "and it stopped exactly at the ceiling it was given, got " .. turns)
        end,
    },
    {
        name = "a fight already decided before the first turn is not run",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_knight", 4, 6)
            local foe = Fixture.unit("character_wolf_grunt", 4, 2)
            local combat = Fixture.combat(map, { hero }, { foe })
            for _, u in ipairs(combat.units) do
                if u.side == "enemy" then u.alive = false end
            end

            local result, turns = Autobattle.run(combat)
            assert(result == "win", "an empty far side is already a win")
            assert(turns == 0, "and no turn was taken to discover it, got " .. turns)
        end,
    },
    {
        name = "a real encounter builds, deploys, resolves and pays -- the whole walk-off, headless",
        fn = function()
            -- The path states/game.lua's autoResolve walks, end to end and with no board: build the
            -- same fight the battle state would, stand the company on it without a player, run it, and
            -- roll the same spoils. Every link here is one the walk-off cannot do without, and a break
            -- in any of them would otherwise only show up by stepping on a wolf marker in a real run.
            local Character = require("models.character")
            local EncounterModel = require("models.encounter")

            local roster = {}
            for i = 1, 4 do roster[i] = Character.instantiate("character_knight") end

            local built = EncounterBattle.build({
                encounter = { kind = "combat", id = "encounter_wolf", tier = 2 },
                prestige = 4,
                party = roster,
            })
            assert(built.combat and built.arena, "the fight built")
            assert(#built.enemyUnits > 0, "with wolves on it")
            assert(not built.combat.opened, "and it is NOT opened -- the caller deploys first")

            local deployed, front = EncounterBattle.autoDeploy(built.combat, built.arena, roster)
            assert(#deployed > 0, "the company stood up")
            assert(#deployed <= Combat.MAX_FIELD, "no more than the field holds")
            assert(#front > 0, "and somebody is on the forward line (resolveOpening reads it)")

            Combat.openBattle(built.combat)
            local result = Autobattle.run(built.combat)
            assert(result == "win", "four knights beat a prestige-4 wolf pack; got " .. tostring(result))

            local spoils = EncounterBattle.spoils({
                encounter = { kind = "combat", id = "encounter_wolf", tier = 2 },
                enemyUnits = built.enemyUnits,
                prestige = 4,
                combat = built.combat,
            })
            assert(spoils, "a won side-fight pays something")
            assert((spoils.gold or 0) > 0, "gold")
            assert(next(spoils.materials or {}) ~= nil, "and the salvage floor every won fight owes")
        end,
    },
    {
        name = "the walk-off tier scaling is the battle state's own",
        fn = function()
            -- One table, one place. If these ever diverge, a fight pays differently depending on
            -- whether you watched it -- which is the exact failure lifting this out of
            -- states/battle.lua was meant to make impossible.
            assert(EncounterBattle.TIER_GOLD[1] == 1.0)
            assert(EncounterBattle.TIER_GOLD[2] == 1.6)
            assert(EncounterBattle.TIER_GOLD[3] == 2.4)
        end,
    },
    {
        name = "only a plain kill-them-all fight may be walked off",
        fn = function()
            assert(EncounterBattle.eligible({ composition = { "character_bandit" } }),
                "an ordinary trail fight is eligible")

            assert(not EncounterBattle.eligible(nil), "a missing blueprint is not")
            assert(not EncounterBattle.eligible({ objective = { win = { type = "defend" } } }),
                "an objective's win clock is driven by the battle state, not the model")
            assert(not EncounterBattle.eligible({ allies = { "character_villager" } }),
                "an escort is a body the player is meant to keep alive by choosing where to stand")
        end,
    },
    {
        name = "the encounters that carry a clock the model cannot read are refused by name",
        fn = function()
            -- The five authored today (the prologue's siege and survivors legs). Named rather than
            -- described, because this is the list that would silently grow: an author adding waves to
            -- an ordinary `combat` encounter must not thereby make it un-walkable-off by accident and
            -- un-noticeably.
            local EncounterModel = require("models.encounter")
            for _, id in ipairs({
                "encounter_siege_breach", "encounter_siege_line", "encounter_siege_pickets",
                "encounter_survivors_defend", "encounter_survivors_extract",
            }) do
                local def = EncounterModel.get(id)
                assert(def, id .. " is still an encounter")
                assert(not EncounterBattle.eligible(def), id .. " must never be auto-resolved")
            end
        end,
    },
    {
        name = "a cell is eligible only when it is a side-fight the model can finish",
        fn = function()
            assert(EncounterBattle.cellEligible({ encounter = { kind = "combat", id = "encounter_wolf" } }),
                "a wolf pack on the trail is walkable-off")
            assert(EncounterBattle.cellEligible({ encounter = { kind = "elite", id = "encounter_elite" } }),
                "so is an elite, once you are far enough above it")

            assert(not EncounterBattle.cellEligible({ encounter = { kind = "objective", id = "encounter_wolf" } }),
                "the quest objective is always played, whatever its def says")
            assert(not EncounterBattle.cellEligible({ encounter = { kind = "treasure" } }),
                "a non-combat stop is not a fight to skip")
            assert(not EncounterBattle.cellEligible({}), "and a cell with no encounter is not one either")
            assert(not EncounterBattle.cellEligible(nil))
        end,
    },
}
