-- The one square nobody else sells. Armor never grants movement -- that is a hard rule with no
-- exceptions (docs/classes.md, "Armor costs a square"), and the only things that hand one back are the
-- Undercroft's boots, one cell at a time, for one body at a time.
--
-- This gives it to the WHOLE COMPANY, which is why it is the most expensive platter with no kitchen
-- skill on it. On an 8x8 board with four bodies a side, a square each is the difference between a line
-- that arrives together and one that arrives in two waves -- and it is the only order on this menu that
-- changes where the fight happens rather than how it goes once it is there.
--
-- Priced and gated well above the opening three deliberately. A supper that hands out pace on day one
-- would be the answer to every early quest and the reason nobody ever read the rest of the board.
return {
    name = "The Walking Lunch",
    description = "Every member of the company walks one square further for the quest.",
    flavor = "Wrapped in paper and tied with string, so that nobody has an excuse to sit down with it.",
    price = 160,
    unlockPrestige = 3,
    bonus = { movement = 1 },
}
