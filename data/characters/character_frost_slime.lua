-- THE FROST SLIME: one of Sloth's three slimes. Its rule is FROSTBITE (data/traits/trait_frostbite.lua): a foe
-- beside it whose blow lands on it is Frozen.
--
-- ITS LEVER IS POSITION (the creature identity pass, 2026-11-19). It laid Numb until then -- every cost one
-- higher, a tax nobody could see. Now the rule says where to stand: throw the element from range, or pay a turn
-- for the hand that swung it. The three Sloth slimes each carry a different one: this one punishes the touch,
-- the Rime Slime the place it dies, the Snowdrift the turns it is left alone.
--
-- Its hide is lightning-soft rather than fire-soft, so the tundra's ice is not one answer printed eight times.
return {
    name = "Frost Slime",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/frost_slime.png",
    stats = {
        health = 44, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 3,
        speed = 4,
        skill = 4, luck = 2,
    },
    resist = { ice = 3, lightning = -3 },
    startingItems = {
        false,              false,              false,
        "weapon_pseudopod", "utility_frost_body", false,
        false,              false,              false,
    },
    defaultAction = "weapon_pseudopod",
    -- ITS OWN PIECES, and only its own (docs/drops.md).
    drops = { "utility_idle_hands" },
    archetype = "aggressive",
    -- It leans on the nearest body, which is the one most tempted to answer it from beside it.
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
