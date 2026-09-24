-- The Unbroken Stalk: the Longfang's rule, and the same rule worn by a person (utility_the_unbroken_stalk).
-- A blow struck while Invisible that DOWNS its target leaves the striker Invisible -- through the round it
-- has just earned, and into the next turn it opens, whatever the blood tally says. So she takes a body a
-- turn and is never once seen. Reviewed as option A of round three ("The Sabertooth" artifact, pitched as
-- Thrill of the Hunt -- a name the hunter's shelf already holds, so the rule carries its drop's name).
--
-- ON THE DEATH, NOT ON THE BLOW. onAnyDeath fires inside the killing blow, before the Pounce's own reveal
-- runs (data/items/weapon/weapon_pounce.lua), so "was she hidden when it fell" is read at the one moment
-- it is still true. The Pounce asks this trait's flag afterwards to decide whether to break cover, so the
-- two halves cannot disagree about which kills were kept.
--
-- THE LATCH IS `unit.veilNext`, spent by Combat.startTurn past the expiry sweep. Without it the kept veil
-- would lapse at the top of her next turn -- the Smoke Mantle's veil is refused to a body that drew blood --
-- and the rule would buy one quiet round rather than a hunt.
--
-- THE ANSWERS ARE THE REST OF THE FIGHT'S: keep everyone above one critical bite, and reach her while she
-- hides -- an area blast still lands (Combat.aoeUnits does not ask), and Witchlight lights her.
return {
    name = "The Unbroken Stalk",
    description = "A blow struck while Invisible that downs its target keeps you Invisible, into your next turn.",
    keepsVeilOnKill = true,
    onAnyDeath = function(ctx)
        local fallen, unit = ctx.fallen, ctx.unit
        if not (fallen and fallen.lastAttacker == unit and fallen.side ~= unit.side) then return end
        local Status = require("models.status")
        if not Status.has(unit, "status_invisible") then return end
        unit.veilNext = true
    end,
}
