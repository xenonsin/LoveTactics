-- AN ADDER: what springs up out of Gorgon's blood (models/gorgon.lua) -- beside Medusa when a blade cuts her, and
-- beside a company body wearing Serpent Locks when a blade cuts it. A small poisoner, as the page asked: the bite
-- is light and the Poison does the work. Never fielded by an encounter; it arrives mid-fight as a summon, held by
-- the body that bled it, and goes when that body does.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS); a snake from a drop of blood sits near the bottom of it.
return {
    name = "Adder",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/adder.png",
    stats = {
        health = 12, mana = 0, stamina = 14,
        staminaRegen = 3,
        damage = 4, magicDamage = 0,
        defense = 1, magicDefense = 2,
        movement = 4,
        speed = 6,
        skill = 5, luck = 5,
    },
    -- Scale on a snake that small turns a point and not an edge (docs/bestiary.md: a redistribution).
    resist = { pierce = 2, slash = -2 },
    startingItems = { "weapon_adder_fang" },
    defaultAction = "weapon_adder_fang",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
