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

-- ARM THE MARK THE WAY THE FIGHT DOES: by crossing the last stage with a real blow. The `mark`
-- response (data/traits/trait_boss_phases.lua) is the only thing that writes unit.scriptedFell, so a
-- case that pokes the field directly would still pass with the phase entry deleted.
local function crossLastStage(c, boss)
    local hp = boss.char.stats.health
    hp.current = math.floor(hp.max * 0.32) + 1
    Combat.dealFlatDamage(c, boss, 1, nil, "test")
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

    {
        -- The `transform` phase response (trait_boss_phases): a stage can shed the boss's body for
        -- another blueprint's -- the human general becoming the demon beneath. It stays the SAME unit
        -- (one tile, one health bar) in a new shape, and because ui/battle_map draws unit.char.sprite
        -- live, the board sprite swaps with it. Scripted onto the Sigil's OWN runtime phase table (the
        -- item instance, not the shared blueprint) so the response is exercised without a bespoke fixture.
        name = "a phase can transform the boss into another body, board sprite and all",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_mage", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local boss = c.units[2]
            local phase = traitOn(boss, "trait_boss_phases")
            assert(boss.char.id == "character_demon_champion", "starts in its own body")
            assert(boss.char.spritePath == "assets/chars/demon_champion.png", "wearing its own board sprite")
            local pool = boss.char.stats.health -- the continuous thing a transform must carry, by reference

            -- Rewrite the stage script to a single transform at half health (runtime instance only).
            phase.item.phases = { { at = 0.5, responses = {
                { kind = "transform", id = "character_demon_lord" },
            } } }
            phase.stacks = 0

            local hp = boss.char.stats.health
            hp.current = math.floor(hp.max * 0.49) + 1
            Combat.dealFlatDamage(c, boss, 1, nil, "test") -- string source: no attacker, counter stays out

            assert(phase.stacks == 1, "the transform stage crossed at half health")
            assert(boss == c.units[2] and #c.units == 2, "the SAME unit -- transform adds no body")
            assert(boss.char.id == "character_demon_lord", "the boss now wears the demon lord's body")
            assert(boss.char.spritePath == "assets/chars/demon_lord.png", "and the board sprite followed the shape")
            assert(boss.char.stats.health == pool, "the health pool carried across (a transform is not a heal)")
        end,
    },

    -- ----- the self-destruct Bomblet (trait_volatile) -----
    {
        name = "a Bomblet bursts when it dies, hitting what stands beside it",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 2, 3) },              -- durable enough to survive and be measured
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
                { unit("character_rowan", 2, 3) },
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
                { unit("character_rowan", 2, 3) },
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
                { unit("character_rowan", 2, 3) },
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
                { unit("character_rowan", 2, 3) },
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
                { unit("character_rowan", 5, 5) },
                { unit("character_demon_bomblet", 5, 2) }) -- three tiles off: within its movement of 4
            local bomblet = c.units[2]
            local plan = AI.plan(c, bomblet)
            assert(plan.item and plan.item.id == "ability_self_destruct", "it plans the burst: " .. AI.explain(plan))
            assert(plan.move, "having walked into range of the ring first")
            assert(plan.tx == plan.move.x and plan.ty == plan.move.y, "aimed at the tile it walks to")

            -- ...and with nobody to catch it, it does NOT waste itself: the outcome gate refuses a burst
            -- that accomplishes nothing, and the posture just walks it closer.
            local c2 = Combat.new(arena(16, 16),
                { unit("character_rowan", 16, 16) },
                { unit("character_demon_bomblet", 2, 2) })
            local far = AI.plan(c2, c2.units[2])
            assert(not far.item, "far from the party it holds its charge and approaches: " .. AI.explain(far))
        end,
    },

    {
        -- Both halves of the burst throw a visual detonation from the bomber's own tile, so the
        -- explosion reads even when the ring catches nobody -- and the two look identical (same cue).
        name = "both halves raise a burst cue on the bomber's tile; a preview raises none",
        fn = function()
            local function burstOn(events, x, y)
                for _, e in ipairs(events or {}) do
                    if e.type == "burst" and e.x == x and e.y == y then return true end
                end
                return false
            end

            -- The passive half: killed by something else, the trait's onDeath paints the ring.
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 5, 5) },              -- out of the blast, so nothing else bursts
                { unit("character_demon_bomblet", 2, 2) })
            Combat.dealFlatDamage(c, c.units[2], 9999, nil, "test")
            assert(burstOn(Combat.drainFx(c), 2, 2), "the passive death throws a burst from the tile it fell on")

            -- The active half: pulling the pin paints the same ring where the bomber stood, even with
            -- nobody in reach to catch a damage cue of their own.
            local c2 = Combat.new(arena(8, 8),
                { unit("character_rowan", 8, 8) },
                { unit("character_demon_bomblet", 3, 3) })
            local bomblet = c2.units[2]
            assert(Combat.useItem(c2, bomblet, bomblet.char.inventory[2], 3, 3), "it pulls its own pin")
            Combat.drainFx(c2) -- clear the wind-up's channel cue
            assert(Combat.resolveChannel(c2, bomblet), "the wound-up burst resolves")
            assert(burstOn(Combat.drainFx(c2), 3, 3), "the deliberate burst throws the same ring, whiff and all")

            -- ...but a dry-run preview must not queue a boom the board would then draw.
            local c3 = Combat.new(arena(8, 8),
                { unit("character_rowan", 3, 4) },
                { unit("character_demon_bomblet", 3, 3) })
            local bomb = c3.units[2].char.inventory[2]
            Combat.previewAbility(c3, c3.units[2], bomb, 3, 3)
            assert(Combat.drainFx(c3) == nil, "hovering the self-destruct raises no cue at all -- least of all a burst")
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
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local champ = c.units[2]
            local roar = champ.char.inventory[2] -- grid cell 2
            assert(roar and roar.id == "ability_demon_roar", "the Champion carries the Roar")
            assert(Combat.useItem(c, champ, roar, 5, 4), "the Roar begins winding up")
            assert(Combat.resolveChannel(c, champ), "the wound-up Roar resolves")
            assert(countAlive(c, "character_demon_bomblet") == 2, "the Roar called two Bomblets")

            -- Interrupted: the channel is broken, and the call is fully wasted -- no Bomblets.
            local c2 = Combat.new(arena(8, 8), { unit("character_rowan", 1, 1) },
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
                party = { "character_avatar", "character_rowan" },
                composition = function()
                    return { "character_demon_champion", "character_demon_imp", "character_demon_imp" }
                end,
                objective = { type = "assassinate", target = "character_demon_champion" },
            })
            assert(a.cols == 8 and a.rows == 8, "an 8x8 board")

            -- The neck (row 4): a wall with a two-wide central gap.
            assert(not a.tiles[4][1].walkable and not a.tiles[4][8].walkable, "the neck's flanks are solid wall")
            assert(a.tiles[4][4].walkable and a.tiles[4][5].walkable, "the gap at x4-5 is passable")
            -- The high ground (row 7): hills the bow shoots from.
            assert(a.tiles[7][3].type == "hill" and a.tiles[7][6].type == "hill", "two hill vantages")

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
    -- ----- the scripted beat: the Champion marks Rowan and spends it on the threshold -----
    {
        -- A TRIGGER FIRES ON ITS THRESHOLD. The blow that crosses the last stage is the blow that pays
        -- for it: the mark goes on and is spent in the same dispatch, before anything else on the board
        -- may act. It waited for the Champion's own turn once, and the wait was the bug -- see the stun
        -- case below, which is the fight that shipped and could be skipped.
        --
        -- The two halves are still separate (the response ARMS, the engine ACTS -- data may not act),
        -- which is why the mark is gone rather than never set: it was armed, and then it was spent.
        name = "the last stage fells Rowan on the blow that crosses it, not a turn later",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_demon_champion", 8, 8) })
            local rowan, boss = c.units[1], c.units[2]
            crossLastStage(c, boss)

            assert(not rowan.alive, "she is down on the crossing itself, with no turn in between")
            assert(not boss.scriptedFell, "the mark was armed and spent inside the one dispatch")
            assert(math.max(math.abs(boss.x - rowan.x), math.abs(boss.y - rowan.y)) <= 1,
                "and it crossed the ground to her rather than striking from where it stood")
        end,
    },
    {
        -- THE FIGHT THIS EXISTS FOR, AND IT SHIPPED BROKEN TWICE OVER -- a stun took the stage away by
        -- two separate routes, and both had to go:
        --
        --   * THE HOOK. Stun suppresses reactions, and suppression skipped the whole onDamaged dispatch
        --     -- so a stunned boss did not cross its threshold AT ALL. No turn, no haste, no enrage, no
        --     mark. A stage is not a reflex (models/trait.lua's Trait.onDamaged, `notAReaction`).
        --   * THE TURN. The mark was then spent at the Champion's own next turn, and a stun SHOVES that
        --     turn down the order rather than skipping it -- so even once the stage crossed, the party
        --     could spend the bought turn killing the boss and end the fight with the beat never played.
        --
        -- Either one alone wins the fight through the hole, so the case asserts the whole chain: the
        -- stage turns, and she is down, on a body that has not been allowed to act since.
        name = "stunning the Champion as it turns does not buy Rowan out of the beat",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_demon_champion", 8, 8) })
            local rowan, boss = c.units[1], c.units[2]
            Status.apply(c, boss, "status_stun", { magnitude = 40 })
            local shoved = boss.initiative
            assert(shoved > rowan.initiative, "the shove lands: its turn is a long way off")

            crossLastStage(c, boss)
            local phase = traitOn(boss, "trait_boss_phases")
            assert(phase.stacks == 2, "the stage turns through the stun: a bar is read, not answered")
            assert(Status.get(boss, "status_hasted"), "and everything the stage does lands with it")
            assert(not rowan.alive, "and she goes down -- the beat is paid by the wound, not by a turn")
            assert(boss.initiative == shoved, "on a body that has not acted: the shove is untouched")
        end,
    },
    {
        -- ...AND IT GOES THROUGH EVERY ANSWER SHE COULD BE WEARING. Nothing about moving the beat onto
        -- the threshold changes what it passes through: a barrier and an interpose are both things that
        -- answer a BLOW, and this is not one (Combat.fell).
        name = "it spends the mark through a ward and an interpose alike",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1), unit("character_knight", 2, 1) },
                { unit("character_demon_champion", 8, 8) })
            local rowan, boss = c.units[1], c.units[3]
            Status.apply(c, rowan, "status_physical_barrier", { magnitude = 5 })
            for _, u in ipairs(c.units) do
                if u.side == "party" then u.guard = { kind = "oathward", cooldown = 0 } end
            end
            crossLastStage(c, boss)
            assert(not rowan.alive, "she is down, ward and interpose notwithstanding")
            assert(rowan.noRevive, "sealed, so nothing puts her back up this battle")
            -- DOWN, NOT DEAD. She is lying on the tile for the rest of the fight -- the state the party
            -- carries off a won board -- and not a body on the necromancer's shelf.
            assert(rowan.incapacitated and not rowan.corpse,
                "she is laid down incapacitated, not turned into a corpse where she fell")
            assert(not Status.get(rowan, "status_downed"),
                "and wears no window: there is no reaching a body the script has sealed")
            assert(math.max(math.abs(boss.x - rowan.x), math.abs(boss.y - rowan.y)) <= 1,
                "it crossed the ground to reach her rather than killing from where it stood")

            -- ONCE. A Champion that lives on does not keep teleporting onto a body already down.
            -- Spending CLEARS the field, which is the whole of the latch.
            assert(not boss.scriptedFell, "the mark is gone the moment it is spent")
            local x, y = boss.x, boss.y
            Combat.spendScriptedFell(c, boss)
            assert(boss.x == x and boss.y == y, "the mark is spent; it does not fire again")
        end,
    },
    {
        -- THE BACKSTOP IS STILL WIRED. The mark is spent on the threshold now (the cases above), so
        -- nothing in the fight reaches a turn still holding one -- but Combat.startTurn keeps its call
        -- for a mark armed where no damage was dealt at all, and a wire nothing exercises is a wire that
        -- quietly comes loose. Poked directly on purpose: there is no live path that leaves one armed.
        name = "a mark still standing at a turn boundary is spent by the opening",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_demon_champion", 8, 8) })
            local rowan, boss = c.units[1], c.units[2]
            boss.scriptedFell = { victim = "character_rowan", seconds = 0.9 }

            rowan.initiative, boss.initiative = 99, 0 -- the Champion is up next
            assert(Combat.startTurn(c) == boss, "its turn opens")
            assert(not rowan.alive, "and she is down before it may act")
            assert(not boss.scriptedFell, "the mark is spent by the opening, not by anything the AI does")
        end,
    },
    {
        -- THE BEAT IS HANDED TO THE VIEW AS SIX MOMENTS, NOT AS A RESULT. The model still resolves the
        -- crossing and the felling in one pass (the test above) -- what this covers is the staging it
        -- leaves behind for states/battle.lua to play: where the body started, the ground it covers on
        -- the way, and the line she speaks with the blow on her. Nothing here asserts a second of
        -- timing, because the model does not own one; it asserts that the view is TOLD ENOUGH to
        -- animate the beat instead of snapping it.
        --
        -- It exists because the beat shipped once with all of this missing: the demon blinked to her
        -- tile and she died in the same frame, and the whole of the fix lives in a field a spec can
        -- check somebody is still writing.
        name = "the crossing hands the view a staging: an origin, a route and her line",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_demon_champion", 8, 8) })
            local rowan, boss = c.units[1], c.units[2]
            assert(not c.scriptedStrike, "nothing is staged before the stage turns")

            crossLastStage(c, boss)
            local staged = c.scriptedStrike
            assert(staged, "the spent mark leaves the view a beat to play")
            assert(staged.unit == boss and staged.victim == rowan, "who crossed, and who it reached")
            assert(staged.fromX == 8 and staged.fromY == 8,
                "and WHERE IT STOOD, which the model has already overwritten -- without it the wind-up "
                .. "and the walk would both play on the destination tile")
            assert(staged.windup and staged.windup > 0, "the wind-up is timed by the script, not the view")

            -- THE ROUTE, which is what makes it a crossing rather than a blink.
            local route = staged.route
            assert(route and #route > 1, "the ground it covers, tile by tile")
            assert(route[1].x == 8 and route[1].y == 8, "origin-first, like every other path in the model")
            assert(math.max(math.abs(route[#route].x - rowan.x), math.abs(route[#route].y - rowan.y)) <= 1,
                "and it ends beside her, on the tile the body is now standing on")
            assert(route[#route].x == boss.x and route[#route].y == boss.y, "the same tile, said twice")
            for i = 2, #route do
                local step = math.abs(route[i].x - route[i - 1].x) + math.abs(route[i].y - route[i - 1].y)
                assert(step == 1, "one tile at a time: the view walks this, so a jump in it is a teleport")
            end

            -- HER LINE, played between the blow landing and the body going down. A scene that does not
            -- exist would simply be skipped by the view, which is how the beat reads as sudden again.
            local Conversation = require("models.conversation")
            assert(staged.scene and Conversation.defs[staged.scene],
                "she speaks after she is hit, and the scene she speaks is one that exists")

            -- AND THE TWO READOUTS THE BEAT WROTE, TAKEN OFF THEM AND CARRIED, which is the half that
            -- only matters now the beat resolves inside the blow that armed it. Left in place, the
            -- crossing's cues ride out in that blow's own drain and its lines print under that blow's
            -- own entry -- the demon beside her and "Rowan is defeated!" in the panel, a wind-up and a
            -- whole run before the board gets there.
            assert(staged.fx and #staged.fx > 0, "the beat's cues travel with the staging")
            local sawDeath = false
            for _, e in ipairs(staged.fx) do sawDeath = sawDeath or e.type == "death" end
            assert(sawDeath, "her death among them -- the one cue that gives the ending away")
            for _, e in ipairs(c.fx or {}) do
                assert(e.type ~= "death", "and it is GONE from the queue, not merely copied out of it")
            end

            assert(staged.log and #staged.log > 0, "and so do the lines it wrote")
            local tail = c.log[#c.log]
            assert(not (tail and tail.kind == "death"),
                "the log ends on the blow, not on a felling nobody has watched yet")
        end,
    },
    {
        -- THE ROUTE IS ROAD, NOT A RULER. A straight line between two tiles walks through the arena's
        -- own walls -- and THE NECK (data/arenas/demon_champion.lua's y4 mountain wall, gap at x4-5) is
        -- the wall this fight is built around, so the one board the beat actually plays on is the board
        -- that would show it.
        name = "a scripted route goes around a wall rather than through it",
        fn = function()
            local a = arena(8, 8)
            for x = 1, 8 do
                if x ~= 4 and x ~= 5 then
                    a.tiles[4][x] = { type = "mountain", moveCost = 1, walkable = false, sightCost = 2 }
                end
            end
            local c = Combat.new(a, { unit("character_rowan", 1, 8) },
                { unit("character_demon_champion", 1, 1) })
            local boss = c.units[2]
            local route = Combat.scriptedRoute(c, boss, 2, 8)
            assert(route, "there is a road: the gap in the wall")
            for _, cell in ipairs(route) do
                assert(a.tiles[cell.y][cell.x].walkable, "and every tile of it is ground it can stand on")
            end
            local gap = false
            for _, cell in ipairs(route) do
                if cell.y == 4 then gap = (cell.x == 4 or cell.x == 5) end
            end
            assert(gap, "the wall is crossed at the gap, which is the only place it can be crossed")

            -- No road at all is answered with nil rather than a straight line, so the view falls back
            -- to gliding the body across instead of walking it through a wall.
            local sealed = arena(8, 8)
            for x = 1, 8 do
                sealed.tiles[4][x] = { type = "mountain", moveCost = 1, walkable = false, sightCost = 2 }
            end
            local c2 = Combat.new(sealed, { unit("character_rowan", 1, 8) },
                { unit("character_demon_champion", 1, 1) })
            assert(not Combat.scriptedRoute(c2, c2.units[2], 2, 8), "a walled-off goal has no route")
        end,
    },
    {
        -- THE WARNING IS QUEUED, NOT PLAYED. Data is pure logic and may not reach the UI, so the
        -- response leaves the scene id on the combat and the view plays it -- as the OPENING of the beat
        -- now (states/battle.lua's playScripted claims it), rather than as a turn of grace ahead of one.
        -- The queueing is what a headless run can see; that it is still owed AFTER the beat has resolved
        -- in the model is the half that matters, since the line and the felling now share one moment.
        name = "marking her queues Rowan's warning for the beat it opens",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_demon_champion", 8, 8) })
            local boss = c.units[2]
            assert(not c.pendingScene, "nothing is owed before the stage turns")
            crossLastStage(c, boss)
            assert(c.pendingScene, "the stage owes the player a line, and still owes it after it resolves")
            local Conversation = require("models.conversation")
            assert(Conversation.defs[c.pendingScene], "and the scene it names is a scene that exists")
        end,
    },
    {
        name = "a felled companion is still carried off the won board -- felled is not killed",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 1, 1) },
                { unit("character_demon_champion", 5, 5) })
            local rowan = c.units[1]
            assert(Combat.fell(c, rowan), "the scripted beat puts her down")
            assert(not rowan.alive and rowan.noRevive, "sealed for the rest of the fight")
            assert(rowan.incapacitated and not rowan.corpse, "lying there, rather than a body to harvest")

            -- THE SEAL HOLDS ON A BODY THAT IS LYING DOWN. It used to hold by implication -- a sealed
            -- body went straight to the corpse path, which reanimate refuses anyway -- and a scripted
            -- felling now lands in the very state reanimate otherwise says yes to.
            assert(not Combat.reanimate(c, rowan), "no Revive, scroll or Salts stands her back up")
            assert(not Combat.rescuableAt(c, rowan.x, rowan.y),
                "and a revive cast is not even offered her tile, so nothing promises what it cannot do")
            -- ...but the body is still THERE. The hover readout reads the same two fallen layers
            -- (states/battle.lua), and the tile of the body this whole scene is about must not go quiet.
            assert(Combat.downedAt(c, rowan.x, rowan.y) == rowan,
                "she is still lying on her tile, and hovering it still opens her")

            -- The seal is a BATTLE rule. Combat.reviveFallenParty reads char.revivable, not this flag,
            -- which is what lets the story fell somebody it needs walking around in the next scene.
            local carried = Combat.reviveFallenParty(c)
            local sawRowan = false
            for _, char in ipairs(carried) do sawRowan = sawRowan or char.id == "character_rowan" end
            assert(sawRowan, "she is carried out of the won fight like any other casualty")
            assert(rowan.alive, "and stands up on the far side of it, to be wounded rather than lost")
        end,
    },
    {
        name = "the scripted felling is prologue-only: one mark, on the Champion's relic, at the last stage",
        fn = function()
            -- The Champion's header offers it as a reusable mid-tier demon boss. Rowan is in the party
            -- for the rest of the game, so a second fight fielding THIS relic would fell her again in a
            -- scene nobody wrote. Reuse it with a twin relic that drops this entry; never with this one.
            local Item = require("models.item")
            local sigil = Item.defs["utility_demon_sigil"]
            local found = {}
            for _, phase in ipairs(sigil.phases or {}) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "mark" then found[#found + 1] = { at = phase.at, r = r } end
                end
            end
            assert(#found == 1, "one scripted felling, not two")
            assert(found[1].at == 0.33,
                "at the LAST stage: felled at two-thirds the avatar finishes 100 health solo and loops")

            -- WHO it takes, read off the entry itself. "Aimed at the body the scene is about" is the
            -- half a seed assertion can never catch.
            local mark = found[1].r
            assert(mark.victim == "character_rowan",
                "the mark is aimed at the body the Cathedral scene is written about")
            -- IT ONLY ARMS. The felling belongs to Combat.spendScriptedFell, in the same beat -- if a later
            -- pass moves the crossing and the felling into the response itself, authored data has begun
            -- acting, and this is the assertion that says so.
            assert(Combat.spendScriptedFell, "the act is the engine's, on the threshold the response arms")
            local Conversation = require("models.conversation")
            -- The warning line, which opens the beat...
            assert(mark.scene and Conversation.defs[mark.scene],
                "it owes a warning first, and the scene it names is one that exists")
            -- ...and the second line, spoken with the blow on her, between the strike and the body going
            -- down (states/battle.lua's SCRIPT_BEATS). Named beside the first for the same reason: the
            -- beat is one thing, and both halves of what it says should be readable off one entry.
            assert(mark.hitScene and Conversation.defs[mark.hitScene],
                "she speaks AFTER she is hit, or the felling reads as sudden again")
            assert((mark.seconds or 0) > 0, "and the body winds up first, for a length the script sets")

            -- Nothing else in the game may carry a scripted felling without a scene to justify it.
            local bearers = {}
            for id, item in pairs(Item.defs) do
                for _, phase in ipairs(item.phases or {}) do
                    for _, r in ipairs(phase.responses or {}) do
                        if r.kind == "mark" then bearers[#bearers + 1] = id end
                    end
                end
            end
            assert(#bearers == 1 and bearers[1] == "utility_demon_sigil",
                "the Sigil is the only relic that fells a named body by script")
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
