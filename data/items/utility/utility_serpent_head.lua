-- SERPENT HEAD: the Chimera's tail, worn. Asked for on review in so many words -- "it should act as a
-- separate head with its own AI; introduce each head as an item" -- so it is the same seam from the other
-- side: at the bell it grows a serpent head on its bearer (`head`, Combat.spawnHeads) with its own card on
-- the strip, its own AI and its own ~30 health. On its turn it coils; while it is coiled, the first foe to
-- strike the bearer in melee is bitten and Poisoned (trait_serpents_strike). It goes when the bearer goes
-- down, and a head broken in a fight stays broken for that fight.
--
-- BEASTMASTER STOCK: "the bonded animal stands as a unit of its own and acts" -- joined to your body.
--
-- EARNED BY BREAKING IT (`onlyWhenBroken`, Spoils): it can fall only from a Chimera whose serpent was
-- killed in the fight, never from the house stock or the rank fallback. Monster Hunter's part break,
-- approved on review.
return {
    name = "Serpent Head",
    description = "Grows a serpent's head that takes its own turns, and bites the first foe to strike you while coiled.",
    flavor = "It looks behind you so you never have to. It has never once asked what is in front.",
    sprite = "assets/items/utility_serpent_head.png",
    type = "utility",
    tags = { "beast", "head", "poison" },
    class = "beastmaster",
    unlockLevel = 4,
    unstocked = true,
    head = "character_chimera_serpent",
    onlyWhenBroken = "character_chimera_serpent",
    traits = { "trait_serpents_strike" },
}
