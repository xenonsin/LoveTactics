-- An ember-spit: the Wrath circle's swarm, and a body whose death is the point.
--
-- It spits fire from four tiles and dies to anything. What matters is that it leaves fire where it falls
-- (data/traits/trait_cinderfall.lua), so clearing the swarm slowly removes the ground you were going to
-- fight the rest of the floor on.
--
-- That one rule sets up both things standing behind it. The Unquenched is HEALED by fire tiles, so
-- clearing the line feeds it. The Anvil grows on blows taken, so being unable to kite means trading, and
-- trading is what pays it. The cheapest body on the floor creates both problems at once.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Bottom of it.
return {
    name = "Ember-Spit",
    kind = "elemental",
    tier = 1,
    sprite = "assets/chars/ember_spit.png",
    stats = {
        health = 11, mana = 0, stamina = 14,
        staminaRegen = 3,
        damage = 3, magicDamage = 7,
        defense = 1, magicDefense = 3,
        movement = 4,
        speed = 5,
    },
    startingItems = { "weapon_ember_spit", "utility_ember_husk" },
    defaultAction = "weapon_ember_spit",
    -- Basic tactics (models/ai.lua): `skirmish` holds the gap, which is what puts it out where the fire
    -- it leaves is inconvenient rather than in a heap next to its own line.
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
