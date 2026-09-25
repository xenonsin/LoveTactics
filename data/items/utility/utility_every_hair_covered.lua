-- Every Hair Covered: the otter's skin in the saga had to be covered in gold, every hair of it, before the
-- ransom was paid. Off the Gilt Wyrm (data/characters/character_gilt_wyrm.lua), reviewed 2026-09-25.
--
-- Every coin heap the bearer loots plates it: +2 Defense for the fight, no cap
-- (data/status/status_every_hair_covered.lua, landed by hazard_coin_heap on the `coveredInGold` flag).
-- Gold Fever still fires on every dwarf on the board, so the looter is the body they come for -- and this
-- is what makes that the body you WANT them to come for. Taking the gold first is also how a company stops
-- a dwarf reaching three stacks, so the piece pays for the play the circle asks for.
return {
    name = "Every Hair Covered",
    description = "Each heap of gold you loot increases your defense for the fight.",
    flavor = "The ransom was a skin's worth of gold. Somebody always has to be the skin.",
    sprite = "assets/items/utility_every_hair_covered.png",
    type = "utility",
    tags = { "guile" },
    class = "mammonite",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_every_hair_covered" },
}
