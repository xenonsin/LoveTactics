-- Vow of the March: the priest half of the Crusader (fighter x priest), and the item that makes Zeal
-- belong to the crusade rather than to the crusader. The Tabard banks on what YOU do -- your kills, your
-- mends. This widens the pool to what the COLUMN does: any enemy that falls anywhere on the field, and
-- any mending that lands on your side, wherever it came from.
--
-- Which is the point of a vow. A crusade is not a scoreboard, and a priest walking at the back of the
-- march who has personally neither killed nor healed anyone is still owed the same faith as the man at
-- the front. Carrying both this and the Tabard is not redundancy -- Combat.chargeDef unions the two
-- `from` lists, so the pool fills from four different kinds of event and deepens by two.
--
-- The vow also KEEPS the one who took it: Kept Faith reads the pool without spending it, a point of
-- magic defense for every two Zeal held. It carries a trait now because it did not, and a charm whose
-- whole content is a widened pool is a 400g purchase that does nothing until the Reckoning arrives to
-- drain it. docs/classes.md says no item may be another item's on-switch and was enforced against
-- spenders only; the Reckoning banks its own Zeal, and this is the same debt paid from the other side.
--
-- One deviation, said out loud the way the contracts expect: the design called for "an ally within three
-- tiles is healed", and this bank has no range on it -- `allyMended` is tallied on the whole side. A
-- tally is a running count on a unit, not a query about the map, so a radius would have meant either a
-- second bespoke tally per radius or a hook that re-walked the field on every mend. The vow reads better
-- without it anyway: a crusader does not stop believing at four tiles.
return {
    name = "Vow of the March",
    description = "Increase magic defense by 1 per 2 Zeal held. Zeal also banks when any enemy falls, or anyone on your side is healed.",
    flavor = "He took the vow at the gate and has not looked at his own hands since.",
    sprite = "assets/items/utility_vow_of_the_march.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "priest",
    discipline = "crusader",
    price = 400,
    unlockQuests = 10,
    traits = { "trait_kept_faith" },
    charge = { key = "zeal", from = { "foeDown", "allyMended" }, max = 10 },
}
