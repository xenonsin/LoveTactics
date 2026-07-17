-- Invisible: slipped out of sight. The opposing side cannot pick this unit as a target at all --
-- `untargetable` drops it out of Combat.abilityTargets and off the enemy AI's board entirely, so it
-- is neither attacked nor chased. Friendly casts ignore the status, so an ally can still heal or
-- buff someone the enemy has lost. The unit is still drawn (it is your own, after all), just faded.
--
-- It lasts until the unit's NEXT turn: onTurnStart self-expires it, exactly like Defending. Deploying
-- a Decoy ends the caster's turn, so the first turn-start it sees is the following one. The `duration`
-- is a generous fallback so it can never get stuck if that turn never comes.
--
-- Destroying the decoy that bought the concealment strips this early -- see the death path in
-- models/combat.lua, which removes it and logs the reveal.
return {
    name = "Invisible",
    abbr = "Inv",
    description = "Unseen: enemies cannot target this unit until its next turn.",
    color = { 0.60, 0.70, 0.92 }, -- badge tint (pale blue)
    duration = 99,          -- generous fallback; it really ends via onTurnStart (see below)
    hideDuration = true,    -- the fallback countdown is meaningless -- hide it in the tooltip
    hideLog = true,         -- announcing "afflicted with Invisible" would give the Decoy away
    untargetable = true,
    -- A lie told about a body -- this one is here and says it isn't -- so Dispel Illusions tears it
    -- down (Status.illusionsOn). The original and still the archetype of the flag.
    illusion = true,
    onTurnStart = function(ctx) ctx.expire() end,
}
