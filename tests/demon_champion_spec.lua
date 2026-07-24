-- Tests for the Demon Champion capstone (the tutorial's conclusion) and the reusable systems it
-- introduces: the data-driven phase trait (data/traits/trait_boss_phases.lua, scripted by
-- data/items/utility/utility_demon_sigil.lua), the self-destruct pair on
-- data/characters/character_demon_bomblet.lua (data/traits/trait_volatile.lua when something else
-- kills it, data/items/ability/ability_self_destruct.lua when it pulls its own pin), the generic
-- Heave throw (data/items/ability/
-- ability_heave.lua), the Roar's interruptible summon (data/items/ability/ability_demon_roar.lua), and
-- the authored arena + hazard seam (data/arenas/demon_champion.lua, models/arena.lua). Pure logic,
-- headless -- mirrors tests/trait_spec.lua and tests/flight_leg_spec.lua.

local Character = require("models.character")
local Combat = require("models.combat")
local Trait = require("models.trait")
local Status = require("models.status")
local Arena = require("models.arena")
local AI = require("models.ai")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

local function traitOn(u, id)
    for _, t in ipairs(u.traits or {}) do if t.id == id then return t end end
end

local function countAlive(c, id)
    local n = 0
    for _, u in ipairs(c.units) do if u.alive and u.char.id == id then n = n + 1 end end
    return n
end

return {
    -- ----- the phase system (trait_boss_phases, scripted by the Sigil) -----
    {
        name = "the Sigil carries the phase system AND the counter-guard to the Champion",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local boss = c.units[2]
            assert(Trait.has(boss, "trait_boss_phases"), "the Champion answers each wound with the next stage")
            assert(Trait.has(boss, "trait_melee_counter"), "and ripostes reckless melee all fight")
            -- The stage script rides on the granting relic, so the trait id can serve every boss.
            local phase = traitOn(boss, "trait_boss_phases")
            assert(phase.item and phase.item.phases, "the phase script lives on the Sigil relic, read via ctx.item")
            assert(phase.stacks == 0, "no stage has fired at full health")
        end,
    },
    {
        name = "the phases arm the Roar at two-thirds and enrage + hasten at a third",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local boss = c.units[2]
            local hp = boss.char.stats.health
            local phase = traitOn(boss, "trait_boss_phases")

            -- Just under two-thirds: stage 1 fires -- the Roar marker is raised, nothing else yet.
            hp.current = math.floor(hp.max * 0.65) + 1
            Combat.dealFlatDamage(c, boss, 1, nil, "test") -- string source: no attacker, so the counter stays out of it
            assert(boss.alive and phase.stacks == 1, "one stage crossed at two-thirds")
            assert(Status.get(boss, "status_roaring"), "the Roar is armed (status_roaring)")
            assert(not Status.get(boss, "status_enraged"), "but it is not enraged yet")
            assert(not Status.get(boss, "status_hasted"), "nor hastened yet")

            -- Just under a third: stage 2 fires -- Roar dropped, fast + enraged, damage climbing.
            local before = boss.bonus.damage or 0
            hp.current = math.floor(hp.max * 0.32) + 1
            Combat.dealFlatDamage(c, boss, 1, nil, "test")
            assert(phase.stacks == 2, "the second stage crossed at a third")
            assert(not Status.get(boss, "status_roaring"), "it stops roaring once it enrages")
            assert(Status.get(boss, "status_hasted"), "it turns fast (status_hasted)")
            assert(Status.get(boss, "status_enraged"), "and enraged (status_enraged)")
            assert((boss.bonus.damage or 0) > before, "the enrage curve sharpened its damage on the crossing blow")
        end,
    },
    {
        -- The honest reading the Hollow Crown documents: onDamaged never fires on the killing blow, so
        -- bursting the boss past a stage skips that stage's threat entirely.
        name = "a killing blow crosses no stage -- burst it and you skip the threat",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local boss = c.units[2]
            local phase = traitOn(boss, "trait_boss_phases")
            Combat.dealFlatDamage(c, boss, 9999, nil, "test") -- straight from full health to dead
            assert(not boss.alive, "the champion is down")
            assert(phase.stacks == 0, "no stage ever fired -- the killing blow granted the boss nothing")
        end,
    },

    -- ----- the self-destruct Bomblet (trait_volatile) -----
    {
        name = "a Bomblet bursts when it dies, hitting what stands beside it",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 3) },              -- durable enough to survive and be measured
                { unit("character_demon_bomblet", 2, 2) })
            local knight, bomblet = c.units[1], c.units[2]
            assert(Trait.has(bomblet, "trait_volatile"), "the Bomblet carries the self-destruct rule")
            local before = knight.char.stats.health.current
            Combat.dealFlatDamage(c, bomblet, 9999, nil, "test")
            assert(not bomblet.alive, "the Bomblet is gone")
            assert(knight.char.stats.health.current < before, "and its blast caught the adjacent knight")
        end,
    },
    {
        name = "Bomblet blasts chain and terminate -- one popped sets off the next, without looping",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_mage", 8, 8) },                -- a far party unit so the fight is valid
                { unit("character_demon_bomblet", 2, 2), unit("character_demon_bomblet", 2, 3) })
            local a, b = c.units[2], c.units[3]
            Combat.dealFlatDamage(c, a, 9999, nil, "test") -- pop A; its blast should finish the adjacent B
            assert(not a.alive, "the popped Bomblet is gone")
            assert(not b.alive, "and the chain took its neighbour with it (and the test returned: no infinite loop)")
        end,
    },

    -- ----- the DELIBERATE burst (ability_self_destruct) -----
    --
    -- The active half of the same rule. Everything here is about the seam between the two: they throw
    -- one identical blast, they never throw it twice, and the channel is what the party answers.
    {
        name = "the Bomblet carries Self-Destruct, and it throws exactly the trait's blast",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 3) },
                { unit("character_demon_bomblet", 2, 2) })
            local knight, bomblet = c.units[1], c.units[2]
            local bomb = bomblet.char.inventory[2] -- grid cell 2 (see the blueprint)
            assert(bomb and bomb.id == "ability_self_destruct", "the fuse sits above the Core")
            -- Same number, both ways round: a player who learned the blast from a bomblet they shot must
            -- not be surprised by one that jumped them.
            assert(bomb.activeAbility.damage == Trait.defs.trait_volatile.magnitude,
                "the deliberate burst is the trait's own magnitude")

            local before = knight.char.stats.health.current
            assert(Combat.useItem(c, bomblet, bomb, 2, 2), "it pulls its own pin")
            assert(bomblet.alive and bomblet.channel, "...over a wind-up: nothing has gone off yet")
            assert(knight.char.stats.health.current == before, "and the knight is untouched during the tell")

            assert(Combat.resolveChannel(c, bomblet), "the wound-up burst resolves")
            assert(not bomblet.alive, "the bomber is gone")
            local dealt = before - knight.char.stats.health.current
            assert(dealt > 0, "and the ring caught the adjacent knight")

            -- ...and it is ONE blast, not two: the ability's own ring plus the trait answering the
            -- bomber's removal would silently double every self-destruct on the board.
            local c2 = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 3) },
                { unit("character_demon_bomblet", 2, 2) })
            local knight2, bomblet2 = c2.units[1], c2.units[2]
            local was = knight2.char.stats.health.current
            Combat.dealFlatDamage(c2, bomblet2, 9999, nil, "test") -- the passive half, for comparison
            assert(was - knight2.char.stats.health.current == dealt,
                "pulling the pin and being killed cost the knight the same -- no second burst")
        end,
    },
    {
        name = "breaking the wind-up defuses the bomb; killing it inside the wind-up does not",
        fn = function()
            -- Interrupted: shoved or stunned mid-channel, the cast is wasted and the bomber stands there
            -- holding it. This is the answer the passive trait never allowed.
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 3) },
                { unit("character_demon_bomblet", 2, 2) })
            local knight, bomblet = c.units[1], c.units[2]
            local before = knight.char.stats.health.current
            assert(Combat.useItem(c, bomblet, bomblet.char.inventory[2], 2, 2), "the burst begins")
            assert(Combat.interruptChannel(c, bomblet, "shoved"), "a shove breaks the channel")
            assert(not Combat.resolveChannel(c, bomblet), "there is nothing left to resolve")
            assert(bomblet.alive, "the bomber is still standing, its pin unpulled")
            assert(knight.char.stats.health.current == before, "and the knight took nothing")

            -- Killed mid-channel: the channel drops, but the DEATH is answered by the trait, so the
            -- blast lands anyway. Killing it in your own teeth is still the wrong answer.
            local c2 = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 3) },
                { unit("character_demon_bomblet", 2, 2) })
            local knight2, bomblet2 = c2.units[1], c2.units[2]
            local was = knight2.char.stats.health.current
            assert(Combat.useItem(c2, bomblet2, bomblet2.char.inventory[2], 2, 2), "the burst begins")
            Combat.dealFlatDamage(c2, bomblet2, 9999, nil, "test")
            assert(not bomblet2.alive, "the bomber is cut down mid-tell")
            assert(knight2.char.stats.health.current < was, "and it burst all the same")
        end,
    },
    {
        name = "a Bomblet plans its own burst -- it walks into the ring and pulls the pin",
        fn = function()
            -- The whole point of the active half: left to itself, the Bomblet must actually DO
            -- something. It closes and detonates rather than standing beside the party forever waiting
            -- to be killed. (A self-target cast is aimed at the tile the caster WALKS to -- see
            -- AI.candidates -- which is what lets this be a plan at all.)
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 5, 5) },
                { unit("character_demon_bomblet", 5, 2) }) -- three tiles off: within its movement of 4
            local bomblet = c.units[2]
            local plan = AI.plan(c, bomblet)
            assert(plan.item and plan.item.id == "ability_self_destruct", "it plans the burst: " .. AI.explain(plan))
            assert(plan.move, "having walked into range of the ring first")
            assert(plan.tx == plan.move.x and plan.ty == plan.move.y, "aimed at the tile it walks to")

            -- ...and with nobody to catch it, it does NOT waste itself: the outcome gate refuses a burst
            -- that accomplishes nothing, and the posture just walks it closer.
            local c2 = Combat.new(arena(16, 16),
                { unit("character_knight", 16, 16) },
                { unit("character_demon_bomblet", 2, 2) })
            local far = AI.plan(c2, c2.units[2])
            assert(not far.item, "far from the party it holds its charge and approaches: " .. AI.explain(far))
        end,
    },

    -- ----- the generic Heave throw (usable on ally OR foe) -----
    {
        name = "Heave throws an adjacent body -- and it works on a friendly, proving it is generic",
        fn = function()
            -- The Champion throws its OWN adjacent Bomblet (a friendly): proof Heave is side-agnostic,
            -- not a demon-only trick. Open ground south, so it travels its full three tiles.
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) },
                { unit("character_demon_champion", 4, 3), unit("character_demon_bomblet", 4, 4) })
            local champ, bomblet = c.units[2], c.units[3]
            local heave = champ.char.inventory[1] -- grid cell 1 (see the blueprint)
            assert(heave and heave.id == "ability_heave", "the Champion carries the generic Heave")
            assert(Combat.useItem(c, champ, heave, 4, 4), "it heaves the adjacent Bomblet")
            assert(bomblet.alive and bomblet.y == 7, "the friendly Bomblet was thrown three tiles clear, unharmed")
        end,
    },

    -- ----- the Roar's interruptible summon (ability_demon_roar) -----
    {
        name = "the Roar resolves into two Bomblets; interrupting the channel denies them",
        fn = function()
            -- Resolves: the wind-up pays off with two summoned Bomblets on the Champion's side.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local champ = c.units[2]
            local roar = champ.char.inventory[2] -- grid cell 2
            assert(roar and roar.id == "ability_demon_roar", "the Champion carries the Roar")
            assert(Combat.useItem(c, champ, roar, 5, 4), "the Roar begins winding up")
            assert(Combat.resolveChannel(c, champ), "the wound-up Roar resolves")
            assert(countAlive(c, "character_demon_bomblet") == 2, "the Roar called two Bomblets")

            -- Interrupted: the channel is broken, and the call is fully wasted -- no Bomblets.
            local c2 = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local champ2 = c2.units[2]
            assert(Combat.useItem(c2, champ2, champ2.char.inventory[2], 5, 4), "the Roar begins")
            assert(Combat.interruptChannel(c2, champ2, "stunned"), "a Stun/shove breaks the channel")
            assert(not Combat.resolveChannel(c2, champ2), "there is nothing left to resolve")
            assert(countAlive(c2, "character_demon_bomblet") == 0, "and the denied Roar summoned nothing")
        end,
    },

    -- ----- the authored arena + hazard seam (data/arenas/demon_champion.lua, models/arena.lua) -----
    {
        name = "the Champion's board is an authored 8x8 with a neck, high ground, and carried hazards",
        fn = function()
            assert(Arena.defs.demon_champion and Arena.defs.demon_champion.fixed,
                "the arena is authored and fixed (never randomly rolled)")
            local a = Arena.build({ prestige = 1 }, {
                biome = "forest", seed = 1, layout = "demon_champion",
                party = { "character_avatar", "character_knight" },
                composition = function()
                    return { "character_demon_champion", "character_demon_imp", "character_demon_imp" }
                end,
                objective = { type = "assassinate", target = "character_demon_champion" },
            })
            assert(a.cols == 8 and a.rows == 8, "an 8x8 board")

            -- The neck (row 4): a wall with a two-wide central gap.
            assert(not a.tiles[4][1].walkable and not a.tiles[4][8].walkable, "the neck's flanks are solid wall")
            assert(a.tiles[4][4].walkable and a.tiles[4][5].walkable, "the gap at x4-5 is passable")
            -- The high ground (row 7): mountains the bow shoots from.
            assert(a.tiles[7][3].type == "mountain" and a.tiles[7][6].type == "mountain", "two mountain vantages")

            -- The hazard seam: the authored smouldering treeline is carried into the built arena.
            assert(#a.hazards == 2, "both authored hazards were carried (models/arena.lua)")
            for _, h in ipairs(a.hazards) do assert(h.id == "hazard_fire", "each is a fire hazard") end

            -- Every spawn lands on walkable ground.
            for _, group in ipairs({ a.party, a.enemies }) do
                for _, s in ipairs(group) do
                    assert(a.tiles[s.y][s.x].walkable, "spawn at " .. s.x .. "," .. s.y .. " is walkable")
                end
            end
        end,
    },
    {
        name = "the flight leg's objective names its own board, felled by assassinate",
        fn = function()
            local map = require("states.prologue").FLIGHT_QUEST.map
            assert(map.objective.layout == "demon_champion", "the objective pins the Champion's authored arena")
            assert(map.layout == "tutorial_flight", "distinct from the overworld trail layout (unchanged)")
            assert(map.objective.win.type == "assassinate"
                and map.objective.win.target == "character_demon_champion",
                "still won by cutting the Champion down")
        end,
    },
    {
        name = "the caravan defense now introduces the self-destruct Bomblet as a wave",
        fn = function()
            local defend = require("models.encounter").get("encounter_survivors_defend")
            local sawBomblet = false
            for _, wave in ipairs(defend.objective.waves or {}) do
                for _, id in ipairs(wave.composition({ prestige = 1 }) or {}) do
                    sawBomblet = sawBomblet or id == "character_demon_bomblet"
                end
            end
            assert(sawBomblet, "a Bomblet wave teaches the self-destruct demon before the boss reprises it")
        end,
    },
}
