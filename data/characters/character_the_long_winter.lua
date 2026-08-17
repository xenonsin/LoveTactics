-- THE LONG WINTER: Sloth's apex, a 2x2 body, and a fight that adds bodies rather than strength.
--
-- Each threshold sheds a pair of drift-things (data/items/utility/utility_long_dark.lua), and a
-- drift-thing takes TURNS rather than health. So the escalation is a tempo escalation: the longer it
-- goes, the less of the fight is yours. On the board where movement is free, that is the only cost that
-- means anything.
--
-- Tier 3's band is 81-154 health.
return {
    name = "The Long Winter",
    kind = "elemental",
    tier = 3,
    sprite = "assets/chars/the_long_winter.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 128, mana = 0, stamina = 22,
        staminaRegen = 2,
        damage = 12, magicDamage = 10,
        defense = 9, magicDefense = 14,
        movement = 2,
        speed = 2,
    },
    startingItems = { "weapon_hoarfrost_antlers", "utility_long_dark" },
    defaultAction = "weapon_hoarfrost_antlers",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
