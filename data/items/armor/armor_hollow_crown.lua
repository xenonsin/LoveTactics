-- The Demon Lord's crown, and its whole fight. It has no sin of its own -- the seven were its
-- appetites -- so it brings only this: as it is worn down it reaches for the generals you already
-- killed and puts them back on, one at a time (data/traits/hollow_crown.lua). The rule now rides on
-- the crown, delivered to the boss through its grid exactly as a party member's signature is.
--
-- `bound = true` (models/item.lua) matters here: it can never be stolen. A party rogue that could
-- pickpocket the Crown would strip the boss of its entire fight -- bound forbids that, the same way it
-- keeps a hero's signature nailed to its cell. Its blueprint places it in the center of its grid.
--
-- No `class`/`price`: it is not gear anyone shops for. The defense curve is flavor -- the player never
-- forges an enemy's relic -- so only its base value is ever seen.
return {
    name = "The Hollow Crown",
    description = "As its wearer is worn down, it raises the fallen generals to fight again.",
    flavor = "As it fails, it wears the dead. It had no sin of its own -- the seven were its appetites.",
    sprite = "assets/items/sig_hollow_crown.png",
    type = "armor", -- a crown: `bound` (not the type) is what locks it in place
    tags = { "signature", "relic" },
    bound = true,
    traits = { "trait_hollow_crown" },
    bonus = { defense = { 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11 } }, -- levels 0..10 (only base is ever used)
}
