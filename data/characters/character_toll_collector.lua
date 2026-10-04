-- THE TOLL-COLLECTOR: the Tollkeepers' line body, on Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice F). The
-- demons who keep the gates of the lower rift take their due in what you do, never in gold.
--
--   EXIT FEE   a foe that walks out of its reach is struck on the way out; coming in is free (utility_exit_fee)
--   THE PIKE   skewers two tiles in a line, so a pair that stands one behind the other pays twice (weapon_toll_pike)
--
-- THE COUNTERPLAY, STATED: commit or stay away. Walk in only where you intend to stay, use shoves to leave (they pay
-- nothing), and never stand in file in front of it.
--
-- A demon, so holy bites and what it swings burns. Hide like old leather: a point catches, a club does not.
return {
    name = "Toll-Collector",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/toll_collector.png",
    stats = {
        health = 44, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 3,
        movement = 4,
        speed = 4,
        skill = 6, luck = 3,
    },
    resist = { pierce = 2, impact = -2 },
    startingItems = {
        false,              false,              false,
        "weapon_toll_pike", "utility_exit_fee", false,
        false,              false,              false,
    },
    defaultAction = "weapon_toll_pike",
    -- ITS OWN PIECE (docs/drops.md): the pike, reading the line the other way.
    drops = { "weapon_collectors_pike" },
    archetype = "aggressive",
}
