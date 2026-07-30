-- Spike Mail: armor that fights back. A solid physical guard, and it grants the Thorns trait
-- (data/traits/thorns.lua): whenever the wearer survives a MELEE physical blow, a share of that damage
-- is turned straight back on the attacker. Wade into a crowd and let their own swings wear them down --
-- the more they hit you, the more they bleed for it.
return {
    name = "Spike Mail",
    description = "On melee hit taken: the attacker takes a share of its own damage.",
    flavor = "The more they hit you, the more they pay for it. Some fighters find that restful.",
    sprite = "assets/items/spike_mail.png",
    type = "armor",
    tags = { "plate" },
    class = "fighter",
    price = 340,
    unlockQuests = 6,
    bonus = { defense = { 7, 8, 8, 9, 10, 11, 11, 12, 13, 13, 14 } },
    resist = { physical = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
    traits = { "trait_thorns" },
}
