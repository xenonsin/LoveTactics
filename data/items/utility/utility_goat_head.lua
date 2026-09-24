-- GOAT HEAD: the Chimera's goat, worn -- the chase. At the bell it grows a goat head on its bearer (`head`,
-- Combat.spawnHeads): its own card, its own AI, its own ~30 health, and its whole kit is the breath -- a
-- cone of fire that Burns, on the goat's own slow turn. Pair it with Hearth Hunger and one person is the
-- whole chimera: cook, then eat. Asked for on review as "have this be a goat", in place of a pitched fire
-- cone you cast yourself.
--
-- BEASTMASTER STOCK, like the Serpent Head, and EARNED THE SAME WAY (`onlyWhenBroken`): it falls only from
-- a Chimera whose goat was broken in the fight.
return {
    name = "Goat Head",
    description = "Grows a goat's head that takes its own turns, breathing fire.",
    flavor = "You will not like what it thinks of you. It will not say.",
    sprite = "assets/items/utility_goat_head.png",
    type = "utility",
    tags = { "beast", "head", "fire" },
    class = "beastmaster",
    unlockLevel = 5,
    unstocked = true,
    head = "character_chimera_goat",
    onlyWhenBroken = "character_chimera_goat",
}
