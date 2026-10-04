-- THE TOLL: the Toll-Troll's organ (data/characters/character_toll_troll.lua). Approved 2026-10-04 ("Sloth's
-- Bestiary", slice B). The rule is data/traits/trait_the_toll.lua and models/sloth_trolls.lua; its reach is the
-- Bridge Maul's. Bound and unstealable: what the troll drops is Bridge Tax, a different and narrower thing.
return {
    name = "The Toll",
    description = "A foe that uses an attack, ability or item within your weapon's reach is struck first.",
    flavor = "Nobody has ever asked what the toll is for. Nobody has ever been asked for it twice.",
    sprite = "assets/items/utility_the_toll.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_toll" },
}
