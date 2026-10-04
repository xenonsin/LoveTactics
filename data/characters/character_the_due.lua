-- THE DUE: what a fallen Tollkeeper was owed, climbing out of it ("Sloth's Bestiary", 2026-10-04, slice F;
-- data/traits/trait_what_it_was_owed.lua). A small, fast demon that goes for whoever made the kill (models/toll.lua's
-- Toll.plan reads `dueTarget`).
--
-- SUMMON ONLY: no encounter deals it and it drops nothing. It arrives as a real body (it must be killed, or paid,
-- for a `killAll` to resolve) and carries no Exit Fee -- it is owed, not a keeper -- so a Due that falls lets
-- nothing out. Its blow on its debtor is the debt paid, and it goes (weapon_dues_claws). Minted at half the fallen
-- keeper's level (models/toll.lua, Toll.DUE_LEVELLED, where the measurement is written down).
--
-- Tier 2's band starts at 31 health (Balance.HEALTH_BANDS); a debt that small sits at the bottom of it. Fast enough
-- to reach the killer in a turn, from most of a skirmish board.
return {
    name = "The Due",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/the_due.png",
    stats = {
        health = 32, mana = 0, stamina = 20,
        staminaRegen = 4,
        damage = 8, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 6,
        speed = 8,
        skill = 6, luck = 4,
    },
    resist = { slash = 1, impact = -1 },
    startingItems = { "weapon_dues_claws" },
    defaultAction = "weapon_dues_claws",
    archetype = "aggressive",
}
