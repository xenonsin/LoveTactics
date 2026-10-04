-- DREAM-EATING: Baku's own (data/characters/character_baku.lua; "Sloth's Bestiary", 2026-10-04). At the start of
-- its turn it feeds on every Asleep or Dormant body within 3, on either side (trait_dream_eating).
--
-- `bound`, `noSteal`, `class = "creature"`: an organ, never kit. The body's trophy is Baku's Ward.
return {
    name = "Dream-Eating",
    description = "At the start of its turn, heals a tenth and gains damage for every sleeper within 3, either side.",
    flavor = "Folk in the old country asked it to eat their nightmares. It never said it would stop there.",
    sprite = "assets/items/utility_dream_eating.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true,
    traits = { "trait_dream_eating" },
}
