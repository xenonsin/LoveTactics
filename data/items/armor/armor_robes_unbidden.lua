-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Charm sheds off the wearer the instant it lands (trait_devotion_unbidden). Their will cannot be
-- taken -- not resisted, not shortened: refused.
--
-- The narrowest item in this file, and it is allowed to be absolute BECAUSE it is narrow. One status,
-- and a rare one. Against an enemy line with no charmer it is a plain set of robes with a magic
-- defense line; against Luxuria's it is the difference between a fight and watching your own knight
-- walk over and kill your priest. There is no middle reading, which is exactly what a hard counter
-- should look like.
--
-- Compare armor_skeptics_harness's `statusResist`, which makes every magical affliction land briefly
-- or not at all and charges you your entire access to magic for it. This refuses one thing and costs
-- nothing, and that is the trade: breadth for price.
--
-- The story is in the name (docs/story.md, the Cathedral and Lust). Devotion unbidden is not devotion
-- that was asked for -- and the whole of Amana's line is about what the church does to people who were
-- never asked. The robes are the one place the Cathedral's own doctrine protects somebody from it.
--
-- Cloth: a square of pace.
return {
    name = "Robes Unbidden",
    description = "Your will cannot be taken: Charm sheds off you the instant it lands.",
    flavor = "Given, never issued. The Cathedral has no record of who decides and has never been asked twice.",
    sprite = "assets/items/armor_robes_unbidden.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    traits = { "trait_devotion_unbidden" },
    bonus = { magicDefense = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 }, defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 }, movement = -1 },
    resist = { magical = { 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 5 } },
}
