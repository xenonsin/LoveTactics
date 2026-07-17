-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Padded Vest",
    description = "Light armor. A little protection, at no cost to your pace.",
    flavor = "Quilted cloth over the vitals: what you wear before anyone has decided you are worth armouring.",
    sprite = "assets/items/padded_vest.png",
    type = "armor",
    -- Light tier: minimal protection, but never slows you down.
    bonus = { defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
    resist = { physical = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
}
