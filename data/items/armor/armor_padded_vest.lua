-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
local Curve = require("models.curve")

return {
    name = "Padded Vest",
    description = "Light armor. A little protection, for a little of your pace.",
    flavor = "Quilted cloth over the vitals: what you wear before anyone has decided you are worth armouring.",
    sprite = "assets/items/padded_vest.png",
    type = "armor",
    tags = { "cloth" },
    -- Light tier: minimal protection, and a single square of pace.
    --
    -- ARMOR COSTS A SQUARE. Every piece in the catalog carries movement = -1 (heavy, -2), and the
    -- reason is that armor penalties STACK (Combat.applyUnitPassives sums `bonus` across the whole
    -- 3x3 grid) -- so the light tier's old selling point, "it never slows you down", was really the
    -- statement that a character could wear four of these for free. Cloth was pinned here first and
    -- the leather, hide and shield pieces followed: there is no free rung left to hunt for. A tier is
    -- distinguished by how much it protects, not by whether it is felt, and base movement was raised
    -- to 4 to pay for it.
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
    resist = { physical = 1 },
}
