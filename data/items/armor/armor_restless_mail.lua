-- RESTLESS MAIL: the answer to Desidia's circle, worn by a knight ("Sloth's Bestiary", slice G, approved word for
-- word). When you are put to Sleep, wake at once, and your next blow deals 50% more (trait_restless).
--
-- A Knight's coat, because the knight is the body that cannot be taken off the line, and this is the one piece in the
-- game that refuses Sleep outright rather than shortening it. Medium, so it pays a square (docs/classes.md).
--
-- An unstocked trophy on the seat's rung (floor 10), noSteal like every stair piece.
local Curve = require("models.curve")

return {
    name = "Restless Mail",
    description = "When you are put to Sleep, wake at once, and your next blow deals 50% more.",
    flavor = "Every link of it is a knight who heard something in the night and got up.",
    sprite = "assets/items/armor_restless_mail.png",
    type = "armor",
    tags = { "medium" },
    class = "knight",
    unlockLevel = 10,
    unstocked = true,
    noSteal = true,
    bonus = { defense = Curve.ramp(5, 15), movement = -1 },
    traits = { "trait_restless" },
}
