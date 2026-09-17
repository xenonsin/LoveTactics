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
-- THE SHAPE OF THE BEAT, and it is three separate moments on purpose:
--   1. THE PHASE CROSSES (the player's blow). This status goes on, and Rowan says the thing is wrong --
--      `scene`, played by states/battle.lua before the next turn opens. A full turn of warning.
--   2. THE CHAMPION'S TURN OPENS. It SHAKES -- a long wind-up shake, not the 0.26s flinch a hit draws
--      (ui/combat_fx.lua's shake cue takes a duration now) -- so the tell is on the body itself.
--   3. It blinks to her and fells her.
-- Telegraph the STAGE, never the strike: the player is told twice, in words and then in the body, and
-- still cannot stop it. That is the trade a scripted beat makes, and both halves of it have to be paid.
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
    seconds = 0.9, -- how long the wind-up shake runs before the blink

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

        -- 1. THE TELL, on the body. A long shake so it reads as a wind-up rather than as a hit taken.
        Combat.pushFx(combat, { type = "shake", unit = unit, duration = def.seconds })
        -- 2. THE CROSSING. Beside her, not on her; a hemmed-in victim is reached from where it stands,
        --    because the blink is the beat's staging and not its mechanism.
        local x, y = Combat.openTileNear(combat, victim.x, victim.y)
        if x then Combat.teleportUnit(combat, unit, x, y) end
        Combat.logEvent(combat, "action", string.format(
            "It is across the ground before she can set her feet -- and %s does not get up.",
            victim.char.name or "she"), { unit, victim })
        -- 3. THE BLOW, which is not a blow. See models/combat.lua's Combat.fell.
        Combat.fell(combat, victim)
    end,
}
