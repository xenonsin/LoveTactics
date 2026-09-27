-- THE SWARM: the Thousand-Winged's bats (character_swarm_familiar, carried on utility_the_swarm). The rules live in
-- models/swarm.lua; this is where they hang:
--
--   swarms           the flag the planner reads (AI.POSTURES.gather flies a bat to the biggest group of its kin)
--   onTurnEnd /      at the end of ANY turn, 4 or more bats standing together fuse into the Thousand-Winged, and
--   onAnyTurnEnd     the Gathering telegraph is redrawn -- heard by every bat, and safe to hear more than once
--   onCombatStart    the swarm opens Scattered: the fight starts with no body, and a turn to thin it
--
-- NOT A REFLEX (`notAReaction`): a stunned bat still counts.
return {
    name = "The Swarm",
    description = "At the end of any turn, 4 or more bats standing together fuse into the Thousand-Winged.",
    swarms = true,
    notAReaction = true,
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_scattered")
    end,
    onTurnEnd = function(ctx)
        require("models.swarm").turnEnd(ctx.combat)
    end,
    onAnyTurnEnd = function(ctx)
        require("models.swarm").turnEnd(ctx.combat)
    end,
}
