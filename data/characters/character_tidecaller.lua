-- THE MERE, rung 2: the body that turns the floor into the weapon.
--
-- TWO CASTS, AND THEY ARE ONE IDEA. Brine Bolt soaks; Stormwake puts a charge through the water. A
-- soaked body takes +6 from lightning AND its tile conducts (data/status/status_wet.lua), and a fen
-- board is mire, shallows and deep water -- all three of which carry `conductable` already. So the
-- Tidecaller needed no new engine at all: the arc has been in Combat.conductLightning since long
-- before the fen, and this body is what finally points at it.
--
-- AND THE ANSWER TO IT IS THE SAME FACT, which is the shape every enemy mechanic in this game should
-- have. A naga takes lightning at -4 (data/races/naga.lua) and a naga pack shares one channel, so the
-- player's own Jolt does to the Mere exactly what this does to the company -- more, because the race is
-- standing in the conductor on purpose. It teaches the board's rule by using it.
--
-- `class = "mage"` IS THE ONE DECLARATION IN THIS FACTION THAT IS GATED ON MEASUREMENT (docs/nagas.md).
-- The mage table grows damage +0 a level against an enemy scaling of +3 -- the trap that made
-- `class = "rogue"` unshippable on character_bandit. Whether it bites a CASTER depends on how much of a
-- cast's damage comes from the unit's `damage` stat versus the item's own forge curve, and that has not
-- been established. Run `. balance` and tests/enemy_scaling_spec.lua on this body at the level cap
-- before trusting it; the fallback is `fighter` with the reason written here.
--
-- `personalGrowth` is NOT the patch. It is capped at two points a level across all stats and its own
-- header says it is an identity rather than a second class.
return {
    name = "Tidecaller",
    race = "naga",
    tier = 2,
    class = "mage",
    sprite = "assets/chars/tidecaller.png",
    stats = {
        health = 44, mana = 24, stamina = 12,
        damage = 6, magicDamage = 14,
        defense = 2, magicDefense = 6,
        movement = 4, -- 3 after the race
        speed = 4,
        skill = 7, luck = 5,
    },
    startingItems = {
        "ability_brine_bolt", "ability_stormwake", false,
        false,                false,               false,
        false,                false,               false,
    },
    drops = {
        "ability_riptide",
        "ability_breaker",
        "armor_scale_hauberk",
    },
    defaultAction = "ability_brine_bolt",
    signatureAbility = "ability_stormwake",
    ai = {
        -- 1. Soak anything not already wet. The setup half, and `lacks_status` is what makes it work
        --    down the party rather than drenching the same body twice.
        { priority = "high", act = "cast", item = "ability_brine_bolt",
          when = { subject = "any_foe", test = "lacks_status", value = "status_wet" } },
        -- 2. Then put the charge through the water. Aimed at whoever is closest to falling, because the
        --    arc will find the rest of them anyway.
        { priority = "high", act = "attack", item = "ability_stormwake", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 3. And a bolt is better than standing there.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
