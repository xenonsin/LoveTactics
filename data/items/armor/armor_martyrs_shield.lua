-- A shield, so it swaps Wait into Defend (docs/weapons.md). Its extra is that bracing takes on the line's
-- wounds: every adjacent ally is bonded (status_shared_burden), and half of everything they take is borne
-- by the knight instead.
--
-- Quest-only: `class` with no `price`.
--
-- The furthest the `covers` idea can be pushed, and the point at which it stops being generosity and
-- becomes a promise. An Oathkeeper Shield gives its neighbours a share of the WALL; this gives them a
-- share of the knight. Nothing is created -- Shared Burden conserves, 40 damage becomes 20 and 20 (see
-- data/status/status_conjoined.lua's header, which argues the two against each other) -- so what the
-- shield actually buys is moving damage from the people who cannot survive it onto the person who can.
--
-- It is therefore the best shield in the game in a party of casters and the worst possible thing to plant
-- while the knight is nearly dead. The failure case is not subtle: a knight at a sliver of health who
-- braces with this has volunteered to die for the archer's next hit.
--
-- Deliberately spread by the STANCE rather than sworn on one ally. A knight has to decide where to stand
-- and then spend the turn, which is two commitments, and both of them are visible to the enemy.
local Curve = require("models.curve")

return {
    name = "The Martyr's Shield",
    description = "Replaces Wait with Defend, taking half of every wound your neighbours suffer.",
    flavor = "The Bastion's oath does not say you will protect them. It says you will be there instead.",
    sprite = "assets/items/martyrs_shield.png",
    type = "armor",
    tags = { "shield", "holy" },
    class = "knight",
    bonus = { defense = Curve.ramp(3, 7) },
    resist = { physical = { 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5 } },
    waitBehavior = {
        kind = "defend",
        speed = 3,
        defense = Curve.paired(7, 12),
        -- `coversStatus`: handed to every adjacent ally rather than to the holder (Combat.defend).
        coversStatus = "status_shared_burden",
    },
}
