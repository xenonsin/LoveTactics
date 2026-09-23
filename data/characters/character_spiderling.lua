-- SPIDERLING: the brood. Summoned only -- by the Larder Mother's Egg Sac and its half-health burst, and
-- by the player's Brood Sac -- so the rift never fields one on its own (the bestiary says so).
--
-- Chaff with one idea: it carries Engorge (utility_brood_hunger), so when a sibling falls near one the
-- survivor feeds. The brood culls itself; kill them apart, or kill them all at once.
return {
    name = "Spiderling",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/spiderling.png",
    stats = {
        health = 10, mana = 0, stamina = 12,
        damage = 5, magicDamage = 0,
        defense = 1, magicDefense = 2,
        movement = 5,
        speed = 5,
        skill = 2, luck = 5,
    },
    resist = { pierce = 2, impact = -2, fire = -2 },
    startingItems = { "weapon_spider_fangs", "utility_brood_hunger", "utility_silkfoot" },
    -- The venom, bottled: the one priced piece of the spider set (the Poisoner stocks it too).
    drops = { "consumable_spiders_supper" },
    defaultAction = "weapon_spider_fangs",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
