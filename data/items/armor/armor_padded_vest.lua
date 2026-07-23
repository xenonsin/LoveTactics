-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Padded Vest",
    description = "Light armor. A little protection, for a little of your pace.",
    flavor = "Quilted cloth over the vitals: what you wear before anyone has decided you are worth armouring.",
    sprite = "assets/items/padded_vest.png",
    type = "armor",
    tags = { "cloth" },
    -- Light tier: minimal protection, and a single square of pace.
    --
    -- CLOTH COSTS A SQUARE. Every woven thing in the catalog carries movement = -1, and the reason is
    -- that armor penalties STACK (Combat.applyUnitPassives sums `bonus` across the whole 3x3 grid) --
    -- so the light tier's old selling point, "it never slows you down", was really the statement that
    -- a character could wear four of these for free. The tier is distinguished by how much it protects
    -- now, not by whether it is felt, and base movement was raised to 4 to pay for it.
    bonus = { defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 }, movement = -1 },
    resist = { physical = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
}
