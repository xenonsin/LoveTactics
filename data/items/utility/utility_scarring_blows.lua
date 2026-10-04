-- SCARRING BLOWS: the Troll Scarlord's organ (data/characters/character_troll_scarlord.lua). Approved 2026-10-04
-- ("Sloth's Bestiary", slice B). Its club lays the wound; this lifts it at the Scarlord's next turn, so the
-- window is exactly one of its turns long (data/traits/trait_scarring_blows.lua).
return {
    name = "Scarring Blows",
    description = "A foe your club strikes cannot be healed or regrow until your next turn.",
    flavor = "It learned what burns it, and then it learned to be the thing that does.",
    sprite = "assets/items/utility_scarring_blows.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_scarring_blows" },
}
