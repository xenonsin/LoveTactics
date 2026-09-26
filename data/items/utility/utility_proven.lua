-- PROVEN: what an orc IS, granted by its race (data/races/orc.lua) into the first free cell of every orc ever
-- minted, the way a goblin's Blood Feud is. Approved as pitched (2026-09-26, "The Orcs of Wrath").
--
-- A killing blow makes an orc Proven: +2 Damage and +2 Defense for the fight, three times (trait_proven). Bound
-- and unstealable: an organ, never kit. The company's own copy is Orc Scars, the Grunt's drop.
return {
    name = "Proven",
    description = "A kill makes you Proven, up to 3 times.",
    flavor = "Every scar is somebody else's last day. It wears them where you can count them.",
    sprite = "assets/items/utility_proven.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_proven" },
}
