-- THE DEMON CHAMPION'S LAST STAGE, HELD FOR A BEAT INSTEAD OF SPENT ON THE SPOT.
--
-- Armed at 33% health by the Ascendant Sigil's phase script (data/items/utility/utility_demon_sigil.lua)
-- and spent on the Champion's OWN NEXT TURN, where it crosses the board to Rowan and puts her down.
--
-- WHY THIS EXISTS AT ALL -- the bug it fixes. The felling used to be a response ON THE PHASE, and a
-- phase crosses inside Trait.onDamaged, which runs inside the resolution of the PLAYER's blow. So the
-- Champion teleported and killed somebody in the same instant the sword that wounded it was still
-- mid-swing: two animations on top of each other, no turn boundary between them, and a beat the player
-- could not read because nothing had finished happening. A scripted moment has to OWN a turn. It cannot
-- be a side effect of the hit that triggered it.
--
-- Status.onTurnStart is the seam: Combat.startTurn fires it before the unit may act, so this lands at
-- the top of the Champion's turn with the board settled and nothing else moving.
--
-- THE SHAPE OF THE BEAT, and it is six separate moments on purpose:
--   1. THE PHASE CROSSES (the player's blow). This status goes on, and Rowan says the thing is wrong --
--      `scene`, played by states/battle.lua before the next turn opens. A full turn of warning.
--   2. THE CHAMPION'S TURN OPENS. It SHAKES -- a long wind-up shake, not the 0.26s flinch a hit draws
--      (ui/combat_fx.lua's shake cue takes a duration now) -- so the tell is on the body itself.
--   3. IT COMES ACROSS THE GROUND, tile by tile, at a run.
--   4. IT SWINGS, and she takes it: a lunge, an impact and a recoil, with no number on it because
--      nothing was billed (see 6).
--   5. SHE SPEAKS, with the blow already on her -- `hitScene`.
--   6. AND THEN SHE GOES DOWN.
-- Telegraph the STAGE, never the strike: the player is told twice, in words and then in the body, and
-- still cannot stop it. That is the trade a scripted beat makes, and both halves of it have to be paid.
--
-- MOMENTS 2-6 ARE THE VIEW'S, AND THE MODEL DOES NOT TRY TO TIME THEM. It resolves the crossing and
-- the felling in one pass here, as it resolves every exchange, and leaves `combat.scriptedStrike`
-- behind -- a plain table naming who crossed, from where, along which route, and what she says when
-- the blow lands. states/battle.lua (battle.playScripted) plays that out over the seconds it takes to
-- read, holding the death cue back until the last of them. Authored the other way round -- with the
-- model sleeping between beats -- it would be a model that knows what a second is, which is the thing
-- this file's own history says not to build.
--
-- WHAT IT LOOKED LIKE BEFORE, and why that was not enough: the body blinked to her tile and she died
-- in the same frame. Every moment of it was correct and none of it was legible -- reported by the
-- author as the death being "too sudden", with nothing to watch between the shake and the corpse.
--
-- IT IS NOT INTERRUPTIBLE AND DELIBERATELY NOT A WIND-UP. A channel is the right shape for the Roar,
-- whose whole stage is the DENIAL -- break it and no Bomblets. This is the opposite: it must land, so it
-- must not be offered through machinery whose entire point is that it can be broken. The fell itself
-- goes through Combat.fell, outside the damage pipeline, for the reasons that file argues in full.
--
-- SINGLE USE, VIA A SPENT LATCH ON THE INSTANCE rather than by removing itself. A hook that pulls its
-- own status out of the list is mutating the list being walked (Status.remove fires onExpire and pops
-- the instance first), and a latch costs one field and cannot do that. What it buys: a Champion that
-- survives to a second turn does not keep teleporting onto a body that is already down. `victim` names who, in data rather than in the hook,
-- because the beat belongs to one scene and the id should be readable from the phase script beside it.
--
-- models/combat.lua IS REQUIRED LAZILY, INSIDE THE HOOK, and it has to be: combat requires status, which
-- loads this folder through the registry, so a file-scope require here closes the loop and the load
-- hangs rather than erroring. Same rule every other status that reaches for combat keeps
-- (data/status/status_struck_ledger.lua).
return {
    name = "Fixation",
    description = "It has stopped fighting the fight and picked somebody.",
    -- Long enough to survive to the bearer's next turn from wherever in the round the phase crossed.
    -- The spent latch is what ends it, so this is a ceiling and never a timer anybody watches.
    duration = 99,
    -- WHO IT GOES FOR. Named here rather than looked up by role: it picks the WALL, not the weakest --
    -- the stage's own line is that it fixes on your softest body, and this is it removing what stands in
    -- front of them first.
    victim = "character_rowan",
    -- The line Rowan speaks when this lands, played over the board before the next turn opens
    -- (states/battle.lua reads combat.pendingScene). Nil-safe: no scene, no beat, the strike still lands.
    scene = "conversation_flight_champion_turn",
    -- ...and the line she speaks WITH THE BLOW ON HER, between the strike landing and her going down.
    -- Played by states/battle.lua as the fifth beat of the crossing (see `strike` below). Nil-safe in
    -- the same way: no scene, she simply drops.
    hitScene = "conversation_flight_champion_fall",
    seconds = 0.9, -- how long the wind-up shake runs before the body commits to the crossing

    onApply = function(ctx)
        -- Queue the warning. Set on the COMBAT rather than played from here: a status is pure logic and
        -- must not reach into the UI, and the scene has to wait for the blow that armed it to finish
        -- resolving anyway. states/battle.lua plays it at the next turn boundary and clears it.
        if ctx.status.def.scene and ctx.combat then
            ctx.combat.pendingScene = ctx.status.def.scene
        end
    end,

    onTurnStart = function(ctx)
        local Combat = require("models.combat") -- lazy: see the header
        local combat, unit = ctx.combat, ctx.unit
        local def = ctx.status.def
        if not (combat and unit and unit.alive) then return end
        if ctx.status.spent then return end
        ctx.status.spent = true -- once, whatever comes of it

        local victim
        for _, u in ipairs(combat.units or {}) do
            if u.alive and u.char and u.char.id == def.victim then victim = u break end
        end
        -- If she is already down -- the player's own fight killed her, or a later pass moved her off
        -- the board -- the stage simply turns and nothing is owed. The latch above is already set, so
        -- this spends the mark either way.
        if not victim then return end

        -- 1. THE CROSSING. Beside her, not on her; a hemmed-in victim is reached from where it stands,
        --    because the crossing is the beat's staging and not its mechanism. Resolved as a blink --
        --    no budget, no legality -- with the ROUTE it covers read off the board first, while the
        --    body is still standing on the far end of it. That route is the whole of what the view
        --    needs to walk the thing across instead of snapping it there.
        local logMark = #(combat.log or {})
        local x, y = Combat.openTileNear(combat, victim.x, victim.y)
        local fromX, fromY = unit.x, unit.y
        local route = x and Combat.scriptedRoute(combat, unit, x, y)
        -- Silent, because the next line is the one about this movement and "it leaps to (4, 7)" would
        -- be the engine contradicting the run the player is watching (Combat.teleportUnit's opts).
        if x then Combat.teleportUnit(combat, unit, x, y, { silent = true }) end
        -- ...and this line stops at the crossing. It used to finish "-- and Rowan does not get up",
        -- which is the felling's own line (killUnit prints "Rowan is defeated!") said early, in the
        -- one readout the staging below cannot hold back for nothing.
        Combat.logEvent(combat, "action",
            "It is across the ground before she can set her feet.", { unit, victim })

        -- 2. THE STAGING, HANDED TO THE VIEW AS DATA. The model has just resolved the whole beat in
        --    one pass, as it resolves every exchange -- which on the board means the demon appeared
        --    beside her and she died in the same instant, with no blow in between. So the moments the
        --    player is owed are named here and states/battle.lua plays them out: the wind-up, the walk
        --    across, the strike, her recoil, her line, and only then the body going down.
        --
        --    A status may not reach into the UI and this does not: it is a plain table on the combat,
        --    read by the battle state (battle.playScripted) and by nothing else, and a headless run
        --    simply never looks at it. Same seam and same reasoning as `pendingScene` above.
        combat.scriptedStrike = {
            unit = unit, victim = victim,
            fromX = fromX, fromY = fromY,
            route = route,
            windup = def.seconds,
            scene = def.hitScene,
        }

        -- 3. THE BLOW, which is not a blow. See models/combat.lua's Combat.fell. Its cues (the death
        --    fade, the bar) are held by the view until the staging above has played its way down to
        --    them -- exactly as an approach walk holds a blow that was struck at the end of it.
        Combat.fell(combat, victim)

        -- 4. HOW MUCH OF THE LOG THIS BEAT JUST WROTE. The combat log is the one readout the fx holds
        --    cannot reach, and it gives the whole thing away: left alone it prints the crossing and
        --    "Rowan is defeated!" while the demon is still standing at the top of the board winding up.
        --    So the view lifts these lines back off the tail and re-files them under the beats they
        --    belong to (states/battle.lua's SCRIPT_BEATS). Counted from the END rather than held as an
        --    index, so the log's own cap (Combat.LOG_CAP trims from the front) cannot shift it.
        combat.scriptedStrike.logAdded = math.max(0, #(combat.log or {}) - logMark)

    end,
}
