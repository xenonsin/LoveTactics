-- Lifted off Avaritia, and it kept her rule (reviewed 2026-09-25, "Avaritia, the Unspent"; approved as the
-- relic that replaces the Bottomless Purse). Her armour was the gold she lay on; this is the gold the
-- company carries, worn the same way -- and with the same bare scale under it (data/traits/
-- trait_crusted_in_gold.lua): hard to hurt until it commits.
--
-- No `price`, `noSteal`: there is one, and nothing takes it off you.
--
-- A MAMMONITE'S TROPHY (2026-10-01, "there can never be creature drops"): a real class, `unstocked` --
-- shown on the rack, refused as a monster drop, sold and bought back by nobody (docs/drops.md).
-- `unlockLevel` is the floor that pays it: Avaritia's seat, floor six.
return {
    name = "Gilded Belly",
    description = "Increase defense and magic defense by 2 per 100 gold held (up to 10). Winding up, lose it and take pierce as critical.",
    flavor = "Coins she lay on for three hundred years, pressed into the hide until the hide gave up and became them.",
    sprite = "assets/items/utility_gilded_belly.png",
    type = "utility",
    class = "mammonite",
    unlockLevel = 6,
    unstocked = true,
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_crusted_in_gold" },
}
