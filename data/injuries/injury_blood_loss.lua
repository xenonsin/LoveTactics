-- BLOOD LOSS: the injury that is a hole in the body and nothing else.
--
-- This is the meter as it shipped for a year -- a flat share of the health pool set aside, unreachable
-- by any heal in the game -- kept whole as one kind of seven rather than replaced by them. A player who
-- has learned what the dark band on the party strip means learns nothing new the day the other six
-- arrive, and the one lesson Act 0 teaches still has something on a bar to point at.
--
-- IT CARRIES NO BADGE, and that is the distinction it is for. Every other kind stamps a status the body
-- fights under; this one takes a slice of the pool and leaves the body exactly as good at its job as it
-- was. So it is the injury that costs you STAYING POWER and nothing else, which is the cost the whole
-- meter was built to charge, and the six that followed are the ones that charge something different.
--
-- THE HEAVIEST RESERVE IN THE SET, at three times the 6% the others take, and the commonest roll at 30
-- of 100. Both of those are the same decision: the band has to be the thing a player expects, so that a
-- Shattered Leg drawing no band is legible as "this one is different" rather than as a bug.
return {
    name = "Blood Loss",
    description = "Blood Loss: part of the health pool cannot be healed into.",
    -- The deepest of the seven, so a field dressing sets it last (Injury.mend) -- a camp binds what a
    -- camp can bind, and blood is not it.
    severity = 3,
    weight = 30,
    reserve = { health = 0.15 },
    -- No effects. See above: the absence is the design.
}
