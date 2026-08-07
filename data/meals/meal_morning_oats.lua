-- The floor of the menu: the cheapest thing the Cafe will put in front of a company, and the one a
-- broke party can always afford on the way out. No kitchen skill -- it is a bowl of oats -- so what it
-- buys is the plainest good a supper can buy, which is that everyone walks in with a little more room
-- to be wrong in.
--
-- Health here is a CEILING raise (maxBonus), not a heal: the extra is headroom to heal into, exactly as
-- Toughness's is. Wounds carry between the fights of a run, so the difference matters -- this does not
-- undo the last quest, it lengthens this one.
return {
    name = "The Morning Oats",
    description = "Raises the whole company's maximum health for the quest.",
    flavor = "The bowl she puts down without asking, for anyone who counted their coins on the way in.",
    price = 40,
    unlockPrestige = 1,
    maxBonus = { health = 14 },
}
