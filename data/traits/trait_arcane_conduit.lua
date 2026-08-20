-- Arcane Conduit: the standing rule of the Battlemage's charm. Items sitting NEXT TO IT in the 3x3 grid
-- cast harder, and each such cast spends a point of the bearer's banked Arcane.
--
-- The pool is declared on the item itself (`charge`), banked from the `cast` tally: every working you
-- throw feeds it, so the battlemage's spellcasting pays for its own escalation. The spend is read in
-- Combat.resolveCast, on the real cast path only -- never in the damage preview, which is the rule every
-- charge in this game obeys and the reason fx.spendCharge exists.
--
-- It is the author's own idea, and it lands somewhere the codebase already had vocabulary for: the aura
-- block (amountBonus, rangeBonus, twin, careful) has always let a charm reshape its neighbours. What
-- this adds is the first aura FUNDED BY A RESOURCE rather than free -- which turns grid position from a
-- layout puzzle into a spending decision, since the conduit can only sharpen as many casts as you have
-- banked.
--
-- Adjacency is the real cost. Nine cells, eight neighbours, and a conduit in the centre reaches all of
-- them but leaves the centre spent on something that deals no damage of its own.
--
-- Two points per sharpen, not one, and the reason is arithmetic: the pool banks off `cast`, so a
-- sharpened working credits a point on its way past. At a cost of one the conduit nets zero and is
-- simply always on -- a passive wearing a resource bar. At two it reads "cast twice, sharpen once".
return {
    name = "Arcane Conduit",
    description = "Increases what items beside this one in the grid deal or heal by 50%. Spends 2 Arcane each time.",
    magnitude = 50, -- percent added to an adjacent item's magnitude, per point spent
    arcaneConduit = true, -- the flag Combat.resolveCast looks for (Trait.flag)
}
