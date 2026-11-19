-- THE RIME SLIME: one of Sloth's three slimes (floors 9-10, the tundra). Its rule is FREEZE SOLID
-- (data/traits/trait_freeze_solid.lua): when it dies, its tile and the empty tiles beside it become Ice Walls.
--
-- ITS LEVER IS POSITION (the creature identity pass, 2026-11-19). It made you Torpid until then -- your next
-- turn a little later, which showed only as the timeline reshuffling. Now where it dies is the question: kill it
-- in the corridor you need and the corridor is shut for five turns, unless you brought fire to melt it.
--
-- It goes for the foe with the fewest ways out (`hemmed`), because that is where its walls close a body in.
return {
    name = "Rime Slime",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/rime_slime.png",
    stats = {
        health = 44, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 3,
        speed = 4,
        skill = 4, luck = 2,
    },
    -- Fire-soft, and fire is also what melts its walls: the one Sloth slime whose element is also its answer.
    resist = { ice = 3, fire = -3 },
    startingItems = {
        false,              false,             false,
        "weapon_pseudopod", "utility_rime_body", false,
        false,              false,             false,
    },
    defaultAction = "weapon_pseudopod",
    -- ITS OWN PIECES, and only its own (docs/drops.md).
    drops = { "armor_unhurried_coat" },
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "hemmed",
          when = { subject = "any_foe", test = "exists" } },
    },
}
