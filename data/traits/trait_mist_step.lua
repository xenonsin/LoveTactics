-- MIST STEP: the Vampire Duelist's rule (data/items/utility/utility_mist_step.lua; Wrath's vampires,
-- 2026-09-26). The first blow it takes each round does nothing: it turns to mist and re-forms 2 tiles away, on a
-- tile of its choosing (beside a bleeding foe if there is one, else as far from the striker as it can get), and
-- the STRIKER Bleeds, its wound opened by the Duelist. Trait.tryMist does the work; the latch re-arms at the end
-- of the Duelist's own turn. The answer is a cheap first blow -- a thrown knife, a familiar -- before the real one.
return {
    name = "Mist Step",
    description = "The first blow you take each round does no damage: you turn to mist, re-form 2 tiles away, and the attacker Bleeds.",
    mistsOnHit = "round",
    mistBleeds = true,
    notAReaction = true,
    onTurnEnd = function(ctx)
        if ctx.trait then ctx.trait.stacks = 0 end
    end,
}
