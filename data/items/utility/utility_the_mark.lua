-- THE MARK: what the Kinslayer drops (data/characters/character_the_kinslayer.lua; "Envy's Bestiary", row kn_body,
-- approved word for word). A foe that lands a killing blow on you takes 7 times that blow back -- his own Mark
-- (data/traits/trait_the_mark.lua), measured on the blow that felled you rather than on the bearer's last hit. A
-- burn, a hazard, a trap or a thrown bomb fells you with no killer, and the Mark finds nobody.
--
-- A DUELIST'S, because a duel is two bodies and one of them falling: this makes the one who stands pay for it.
-- An unstocked trophy on the seat's rung.
return {
    name = "The Mark",
    description = "A foe that lands a killing blow on you takes 7 times that blow back.",
    flavor = "Nobody is to touch the one who wears it. It has never once said what happens to the ones who do.",
    sprite = "assets/items/utility_the_mark.png",
    type = "utility",
    tags = { "charm" },
    class = "duelist",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_the_mark" },
}
