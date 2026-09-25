-- UNDERFOOT: what a kobold IS, granted by its race (data/races/kobold.lua) into the first free cell of
-- every kobold ever minted, the way a dwarf's Stout is. Kept on review in round 2 (2026-09-25) once it
-- was said plainly what it does: it is the item that carries the kobold's two rules, because in this game
-- a rule reaches a fighter only through something in its grid (docs/classes.md).
--
--   PACK       +2 damage for every other kobold beside the foe it strikes, to +6 (trait_pack)
--   DEVOTION   near a dragon, the Dragon's Eye; a dragon struck is Fervor, a dragon destroyed is Forsaken
--              (trait_devotion, trait_dragonkin, models/devotion.lua)
--
-- Craven was cut in round 1 ("Pack is enough"), and so was every gold rule ("Kobolds don't care about
-- gold"). Bound and unstealable: an organ, never kit -- what the company takes off a kobold is what it
-- carries.
return {
    name = "Underfoot",
    description = "Increase damage for each other kobold beside your target. Near a dragon on your side, increase damage and defense.",
    flavor = "It is always underfoot, and there are always more of it than you counted.",
    sprite = "assets/items/utility_underfoot.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_pack", "trait_devotion" },
}
