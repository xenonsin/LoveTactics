-- The Crimson Standard: a short banner carried at the shoulder, trailing red smoke. Every ally
-- standing in the smoke drinks back a share of what they deal (data/hazards/hazard_bloodsong.lua).
--
-- THE FIRST TEAM-WIDE AURA IN THIS GAME, and it is worth being precise about why it took this shape
-- rather than a new system. The 3x3 grid's auras are the signature idea of the whole design, and they
-- are deliberately intimate: one charm, the items it touches, one character. A LINE-wide effect is a
-- different scale of thing and needed a different mechanism -- and the mechanism already existed, in
-- the censer family, doing exactly this for exactly one class. Nothing was invented here. Something
-- narrow was widened.
--
-- Sustain the company buys by FIGHTING IN FORMATION, which is a real tactical statement rather than a
-- stat. The song reaches one tile around whoever carries the colours, so a party that spreads out to
-- flank gets nothing and a party that holds a line gets everything -- and this game's area damage is
-- built to punish exactly the formation this rewards. The two pressures are supposed to argue.
--
-- A quarter share, against the Red Thirst's three-quarters, and that gap is deliberate: this is
-- ALWAYS ON, for FOUR PEOPLE, for the whole battle. The Thirst is a turn somebody spent.
--
-- It stacks with everything -- the Vampiric Strike charm, a weapon's own declared lifesteal, the Red
-- Thirst (see Status.lifesteal, which sums rather than takes the largest). A fighter under all four is
-- very nearly unkillable while they are landing blows, and completely ordinary the moment they are
-- not, which is the correct shape for a thing built entirely out of thirst.
return {
    name = "The Crimson Standard",
    description = "Allies standing beside its bearer drink back a share of the damage they deal.",
    flavor = "Wrath's only sacrament. The Colosseum sells it to anyone who can lift it and does not ask why.",
    sprite = "assets/items/utility_crimson_standard.png",
    type = "utility",
    tags = { "banner" },
    class = "fighter",
    price = 460,
    repRank = 4,
    -- Radius 1: the smoke reaches the bodies actually beside the bearer, and no further. The forge
    -- cannot widen it -- an upgrade buys a stronger blessing, never a wider one, which is the censer's
    -- own rule (see the `incense` contract in models/item.lua) and the only thing keeping a
    -- company-wide aura from eventually covering a company-wide area.
    incense = { hazard = "hazard_bloodsong", radius = 1 },
    bonus = { damage = { 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5 } }, -- what the forge buys instead of reach
}
