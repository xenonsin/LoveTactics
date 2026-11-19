-- WISP-CARRIER: the Lesser Archon's organ (data/characters/character_lesser_archon.lua; the creature identity pass,
-- 2026-11-19). It carries the rule (trait_wisp_carrier): a fallen Archon's wisp within 3 comes to the Lesser Archon
-- instead of walking home, and the body stands at once.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Mana Edge).
return {
    name = "Wisp-Carrier",
    description = "A fallen Archon's wisp within 3 comes to it, and its body stands at once.",
    flavor = "The least of the court is the nearest door home. That is the only reason it is kept.",
    sprite = "assets/items/utility_wisp_carrier.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_wisp_carrier" },
}
