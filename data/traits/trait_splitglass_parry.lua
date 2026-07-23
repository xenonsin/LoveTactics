-- Splitglass Parry: the Splitglass Saber's answer. It parries in the ordinary way -- the blow lands, the
-- blade cuts back -- and the same motion leaves the SWORDSMAN carrying Splitglass (status_splitglass),
-- which turns aside the next few hits of any kind entirely.
--
-- So answering is also warding, and the weapon reads inside-out compared with every other sword: the more
-- foes test the guard, the harder the guard becomes to test. What bounds it is the thing that bounds every
-- answer -- the escalating stamina price (Trait.answerCost doubles it per answer in a round) -- so a
-- swordsman in a doorway raises the glass on the first attacker and is empty by the third. It buys the
-- first exchange of a press, never the whole press.
--
-- Unlike the three parries beside it this one DOES swing, so it declares a plain `counter` rule and lets
-- the preview quote the swing's damage. The ward it grants is not a threat to the attacker and so has no
-- business in a warning aimed at them.
return {
    name = "Splitglass Parry",
    description = "When struck by a foe your blade can reach, spend a swing's stamina to cut back and raise Splitglass on yourself.",
    counter = {},
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.log("action", string.format("%s parries, and the glass closes over!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
        ctx.applyStatus(ctx.unit, "status_splitglass")
    end,
}
