-- The Dead Man's Hand, as a badge: what the relic of the same name (data/relics/relic_dead_mans_hand.lua)
-- hangs on a body brought to 0 that it holds up. Worn for as long as it stays on its feet; the magnitude is how many of
-- its own turns it has left, and at the end of the last one it falls (models/combat.lua's
-- Combat.spendBorrowedTurn / Combat.callTheHand).
--
-- THE BADGE IS THE READOUT, NOT THE TRUTH. The count lives on the unit (`unit.borrowedTime`), so a
-- status stripped by some effect that removes a named status cannot let the body off the fall. The
-- badge refuses healing as well, which is the rule said where the player looks; Combat.applyHeal
-- refuses a borrowing body by name either way.
--
-- Never ages on the clock -- the count is in the body's own TURNS, which the clock cannot measure --
-- so its duration is a backstop far past any fight, and nothing strips it: not a debuff (Cure), and
-- not a blessing a dispel can take.
return {
    name = "Dead Man's Hand",
    abbr = "DMH",
    description = "Should be dead. Stands at 0 health and acts on until its turns run out, then falls. Cannot be healed, and foes do not aim at it.",
    color = { 0.62, 0.58, 0.70 }, -- badge tint (ashen violet)
    duration = 9999,
    magnitude = 1,
    blocksHealing = true,
    undispellable = true,
    -- FOES DO NOT AIM AT IT. A blow on a borrowing body changes nothing (models/combat.lua), so a
    -- planner that saw a body at 0 as the easiest kill on the board would spend every turn swinging at
    -- a corpse -- which would make the relic a decoy rather than a reprieve. An area cast centred
    -- elsewhere still catches it, harmlessly; an ally's cast still reaches it.
    untargetable = true,
    onTurnEnd = function(ctx)
        require("models.combat").spendBorrowedTurn(ctx.combat, ctx.unit)
    end,
}
