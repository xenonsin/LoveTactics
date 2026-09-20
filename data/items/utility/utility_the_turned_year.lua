-- THE TURNED YEAR: what the Vengeful Spirit wears where the stag wore its hide, and the reason the
-- poisoned board is the spirit's road rather than its cage.
--
-- Three things, and they are one thing said three ways.
--
--   * IT LAYS BLIGHT WHERE IT WALKS. The same `trail` seam the stag's relic used, pointed at the
--     ground the stag's own trail became. The animal that mended the floor by moving now sours it by
--     moving, with nothing changed about the mechanism -- which is what makes the second half read as
--     the same creature rather than a different encounter.
--
--   * IT IS IMMUNE TO THAT GROUND. `statusImmunity` on status_blighted, so the one body on the board
--     that cannot be hurt by the blight is the one that made it. Partly arithmetic -- an unsided
--     poison would otherwise kill the boss for the party, and the whole point of unsided ground is
--     that it has no owner -- and partly the image the fight is built toward: the only safe place left
--     is the thing you were running from.
--
--   * AND NO GREEN EVER COMES BACK. There is no second bloom anywhere in this file, and that absence
--     is authored. A spirit that laid a little New Growth would hand the party a way to claw the first
--     half back, and the threshold is one-way: what the wood gave, it has taken, and it does not offer
--     again.
--
-- THE TRAIL IS WHY THE MAGAZINE IS FINITE, which is the least obvious consequence and the most
-- important one. Blight does not spread (hazard_blight declares no `spread`), and the spirit only
-- makes more of it by WALKING -- one tile per tile, at movement 6 -- while Swailing spends a whole
-- tile per cast. It cannot outpace its own ammunition. So the count that decides the second half is
-- still, overwhelmingly, the count the stag laid while running away from the company in the first.
--
-- `bound`, `noSteal`, `class = "creature"`, no axis: a boss's kit is never handed to the player
-- (docs/bestiary.md). What this fight hands over is on the blueprint's `drops` list instead.
return {
    name = "The Turned Year",
    description = "The ground sours where it walks, and it is the one thing the souring cannot touch.",
    flavor = "Autumn does this every year without meaning anything by it. This means it.",
    sprite = "assets/items/utility_the_turned_year.png",
    type = "utility",
    class = "creature",
    tags = { "signature", "relic", "nature" },
    bound = true,
    noSteal = true,
    trail = { hazard = "hazard_blight", duration = 60 },
    -- Named rather than answered with a resist line, because a resist is a number a big enough hit
    -- walks through and this has to be absolute: the board is unsided and the spirit stands in it for
    -- the whole second half. See models/item.lua's statusImmunity.
    statusImmunity = { "status_blighted" },
}
