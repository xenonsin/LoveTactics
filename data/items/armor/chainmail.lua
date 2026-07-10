-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
return {
    name = "Chainmail",
    description = "Interlocked rings that shrug off cuts and thrusts. Medium armor: -1 movement.",
    sprite = "assets/items/chainmail.png",
    type = "armor",
    class = "knight",
    price = 130,
    repRank = 1,
    -- Medium tier: better all-round steel than leather, still one square slower.
    bonus = { defense = 8, movement = -1 },
    resist = { slash = 3, pierce = 3, physical = 2 },
}
