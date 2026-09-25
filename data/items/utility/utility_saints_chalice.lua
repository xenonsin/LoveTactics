-- Luxuria's old rule, kept on its own piece when she became the Queen of the succubi (settled on review
-- 2026-09-25): Rapture (data/traits/trait_rapture.lua), reworked "as an aoe drain". Every blow draws off
-- the stamina and mana held back by the foe it lands on and by every foe beside it, and pours half of it
-- back into the bearer as health.
--
-- A general's find: `unstocked`, shown on the Cathedral's rack and never sold (docs/drops.md), and on the
-- priest's shelf because the fiction's Saint drank at that altar.
return {
    name = "The Saint's Chalice",
    description = "Your blows draw off the stamina and mana held back by the foe you hit and every foe "
        .. "beside it, and heal you for half.",
    flavor = "It was never once filled from the font. Nobody at the altar asked where from.",
    sprite = "assets/items/utility_saints_chalice.png",
    type = "utility",
    tags = { "dark" },
    class = "priest",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_rapture" },
}
