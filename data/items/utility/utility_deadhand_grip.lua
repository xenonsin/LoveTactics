-- The Deadhand Grip: Final Fantasy Tactics' Maintenance, the support ability that made a unit's
-- equipment impossible to break or steal. Wrapped leather and wire, wound so the haft cannot leave the
-- hand -- the Undercroft's answer to being on the receiving end of its own favourite trick.
--
-- It refuses Disarmed (data/status/status_disarmed.lua), and Disarmed is the only half of FFT's
-- Maintenance this game actually has a status for. Un-stealability is not a status here at all -- it is
-- the item-level `noSteal` flag, decided per blueprint by whoever authored it (a beast's fangs, a bound
-- relic), and there is no debuff to be immune to. So this covers the half that exists rather than
-- pretending to cover both.
--
-- WHY IT IS THE ROGUE'S, when the class that suffers most from disarming is whoever is holding the
-- biggest weapon: because the rogue is the one who knows what it is worth. Greed's shelf is built on
-- "taking what is not yours" (docs/classes.md) -- pickpocket, steal, the Cutpurse Knife, the Bottomless
-- Purse. A shelf whose entire thesis is that things leave people's hands is the right shelf to sell the
-- one item that says: not mine, not ever. It is the thief buying a lock.
--
-- The trade is the grid slot, and that is the whole cost of every item in this family (see the three
-- siblings: the Tempered Gut, the Untroubled Mind, the Rooted Stance). It grants no stats worth
-- speaking of and does nothing at all in a fight where nobody tries to disarm you. Carrying one is a
-- read on the encounter rather than a build -- which is the point, because a blanket defence against
-- everything is what the resistance curve already sells, at a curve's price.
return {
    name = "Deadhand Grip",
    description = "The weapon cannot be struck from this hand: immune to Disarmed.",
    flavor = "The Undercroft teaches you to take a blade off a man. It charges extra to teach the reverse.",
    sprite = "assets/items/deadhand_grip.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    price = 300,
    repRank = 2,
    statusImmunity = { "status_disarmed" },
}
