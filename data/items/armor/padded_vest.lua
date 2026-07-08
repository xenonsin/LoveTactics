-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Padded Vest",
    description = "Quilted cloth over the vitals. Light armor: no movement penalty.",
    sprite = "assets/items/padded_vest.png",
    type = "armor",
    -- Light tier: minimal protection, but never slows you down.
    bonus = { defense = 2 },
    resist = { physical = 1 },
}
