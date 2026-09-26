-- WARPAINT: the Berserker's second drop, round 2 (2026-09-26, "The Orcs of Wrath"), on Keno's note beside the
-- Unbroken Axe: "I'd also like a similar utility." The streak on any weapon or ability: +2 Damage for each turn in
-- a row you landed a hit, up to +10 (trait_warpaint). Worn with the axe it does not add; the longer streak counts.
return {
    name = "Warpaint",
    description = "Each turn in a row you land a hit, increase damage by 2, up to 10. A turn without one resets it.",
    flavor = "It goes on before the fight and comes off in the fight, and the orcs read what is left.",
    sprite = "assets/items/utility_warpaint.png",
    type = "utility",
    tags = { "trinket" },
    class = "barbarian",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_warpaint" },
}
