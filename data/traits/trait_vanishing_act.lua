-- Vanishing Act: Final Fantasy Tactics' Sunken State, which turned invisible the moment its bearer
-- was hit. Carried here by the Undercroft's Guttering Lamp
-- (data/items/utility/utility_vanishing_act.lua).
--
-- The reflex is the rogue's whole posture stated defensively. Every other answer on the shelf is an
-- answer -- a riposte, a counter, a preempt -- and each one requires the rogue to still be standing
-- somewhere the attacker can reach. This one declines the exchange entirely: the blow lands, and then
-- there is nobody there to land the second one on. Invisible drops the bearer out of
-- Combat.abilityTargets and off the enemy AI's board completely (see data/status/status_invisible.lua),
-- so what it really buys is the follow-up, which is what actually kills a rogue.
--
-- Two guards keep it honest, and both of them are the status's own rather than anything invented here:
--   * It lasts until the bearer's NEXT turn (Invisible self-expires on turn start), so the moment the
--     rogue acts again it is visible. Concealment is bought with the turn you spend not using it, and
--     a rogue that vanishes and then immediately stabs somebody has spent it.
--   * It is an `illusion`, so Dispel Illusions tears it straight back down -- the same counterplay the
--     Decoy has always had. Nothing new to learn.
-- A cooldown on top of those stops a multi-hit exchange from re-hiding the bearer between each blow of
-- the same flurry.
--
-- Fired from onDamaged (Trait.onDamaged), which already declines while the bearer is hard-controlled --
-- a stunned rogue does not slip anywhere, which is correct and is also the counterplay: land the stun
-- first and the lamp never gutters.
return {
    name = "Vanishing Act",
    description = "Struck and still standing, the bearer slips out of sight until its next turn.",
    cooldown = 10, -- ~2 turns: one flurry cannot re-hide the bearer between its own blows
    onDamaged = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive) then return end -- it hides the living; a corpse is nobody's problem
        if ctx.onCooldown("vanishing_act") then return end
        -- Already gone: a second hit in the same beat must not spend the cooldown re-applying it.
        if ctx.trait and unit.statuses then
            for _, s in ipairs(unit.statuses) do
                if s.id == "status_invisible" then return end
            end
        end
        ctx.applyStatus(unit, "status_invisible")
        ctx.setCooldown("vanishing_act", ctx.def.cooldown)
        -- Invisible is `hideLog` precisely so it does not announce itself, and the announcement is the
        -- one thing that would undo it. Say that the lamp went out, which is what the room sees.
        ctx.log("action", string.format("%s's lamp gutters, and %s is not where it was.",
            (unit.char and unit.char.name) or "The rogue",
            (unit.char and unit.char.name) or "the rogue"), unit)
    end,
}
