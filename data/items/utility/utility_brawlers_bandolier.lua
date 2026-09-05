-- Brawler's Bandolier: the fighter half of the Warbrewer (fighter x alchemist). A bandolier of vials
-- that turns drinking into part of the fight rather than an interruption of it: when the bearer downs a
-- draught, they gain Haste (trait_brawlers_bandolier, onCast) -- the tempo the drink cost, handed
-- straight back. The faithful reading of "quaff as a free action" that the turn economy actually
-- supports. A PASSIVE, so it attaches to a grid charm (docs/classes.md).
return {
    name = "Brawler's Bandolier",
    description = "When you drink a draught, you gain Haste. Nearly buying back the turn it cost.",
    flavor = "The Crucible sells the potion. The bandolier is for people who did not plan to stop moving to use it.",
    sprite = "assets/items/utility_brawlers_bandolier.png",
    type = "utility",
    tags = { "charm" },
    class = "warbrewer", -- fighter x alchemist; the Combat-draught mechanic's first stock
    unlockQuests = 4,
    dropTier = 3,
    traits = { "trait_brawlers_bandolier" },
    -- a drink and a swing, neither of them slow
    bonus = { speed = 1, damage = 1 },
}
