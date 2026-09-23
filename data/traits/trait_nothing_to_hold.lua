-- NOTHING TO HOLD: the bearer wears Unheld from the opening bell, and so cannot be moved by anything.
--
-- WHY THE RULE IS A STATUS AND NOT A FLAG ON THIS TRAIT. `blocksForcedMove` is read off the status list
-- in eleven places across Combat -- every shove, drag, throw, charge and their previews (models/status.lua,
-- Status.blocksForcedMove) -- and a second reading keyed off traits would be a copy of a rule the engine
-- already owns, which is exactly how a preview comes to disagree with the shove it is previewing. One
-- owner: the status. This just puts it on.
--
-- IT ARGUES WITH ITS OWN CIRCLE, AND THE ARGUMENT IS THE POINT. Lust is built on displacement -- the
-- harpy hauls you in and drives you off, the lamia says you may not leave, the succubus takes your tile
-- and gives you hers. A body on that ground that CANNOT BE DISPLACED is the stratum meeting the one
-- thing it has nothing to say to: a lamia's coil closes on a draught, the Matriarch's wing-beat throws
-- everything adjacent to her except this, and a company's own mace answers it with nothing. The floor's
-- rules are not additive and were never meant to be (see the Lust entry in models/descent.lua, and the
-- lamia's own header on why being held is shelter from the flock).
--
-- SO THE COUNTERPLAY IS TO STOP TRYING TO MOVE IT. Everything else on this ground is answered by where
-- you stand; this is answered by hitting it, which is the one lesson the circle has never had to teach.
--
-- onCombatStart rather than a passive read: the status has to be ON the body before the first shove is
-- previewed, and Trait.setup fires this after passives, traps and hazards are in place -- which is the
-- beat a rule that reads the field is promised.
return {
    name = "Nothing to Hold",
    description = "Cannot be moved: no shove, drag, throw or charge shifts it.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_unheld")
    end,
}
