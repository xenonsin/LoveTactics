-- DEEP BANK: the Old Sloth's organ (data/characters/character_old_sloth.lua; trait_banked_turns). Approved
-- 2026-10-04 on "Sloth's Bestiary", slice A: the Ground Sloth's bank, held to 5, and the fight opens with it full
-- and the Old Sloth Dormant (status_dormant). What it spends the bank on is its sweep (weapon_megatherium_sweep).
return {
    name = "Deep Bank",
    description = "Opens Dormant with 5 turns banked. Banks each turn no foe is in reach, up to 5. A blow knocks one out.",
    flavor = "It went to sleep before the ice came. It has a great many turns to spend.",
    sprite = "assets/items/utility_deep_bank.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_banked_turns" },
    traitParams = { cap = 5, opensDormant = true },
}
