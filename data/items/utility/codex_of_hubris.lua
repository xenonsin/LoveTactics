-- Arcanum rank-4. A passive tome: raw magical power, and a ward against magic in turn. No ability
-- of its own -- it does not need one, and it would like you to know that.
--
-- The Arcanum's catalogue lists eleven owners. It does not list how many finished reading it -- the
-- first hint of Pride, whose general answers every spell with your own.
return {
    name = "Codex of Hubris",
    description = "A tome that reads its bearer back. Potent magic, and a ward against it.",
    sprite = "assets/items/codex_of_hubris.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 800,
    repRank = 4,
    bonus = { magicDamage = 10, magicDefense = 5 },
    resist = { magical = 4 },
}
