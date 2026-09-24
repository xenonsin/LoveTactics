-- THE MOSS KING: the King Slime (data/characters/character_king_slime.lua) as the wood grows it -- an
-- elite on Gluttony's first floor (data/encounters/encounter_the_moss_king.lua).
--
-- The fen's King voids steel and is met on the swamp's seat floor; this one resists it
-- (utility_moss_crown) and is met on the floor a descent opens on, by a company that may not own an
-- element yet. With only steel it is a long grind through four bodies; with fire it is a lesson.
--
-- GLUTTONY'S RULE IS COALESCE (data/items/ability/ability_coalesce.lua): he eats the moss slimes of his
-- own court to heal past his cap, and the three he splits into go on eating each other. Every circle's
-- slimes carry one mechanic of their own; this circle's is its own verb.
--
-- `boss = true` for the King's reasons (Coup de Grace must not skip the split), and fielded under
-- `killAll` -- it must never be made an `assassinate` mark.
return {
    name = "Moss King",
    race = "beast",
    tier = 4,
    boss = true,
    sprite = "assets/chars/moss_king_slime.png",
    stats = {
        health = 160, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 16, magicDamage = 0,
        defense = 2, magicDefense = 3,
        movement = 3,
        speed = 3,
        skill = 5, luck = 2,
    },
    resist = { acid = 5, ice = -5 },
    startingItems = {
        false, "ability_corrosive_touch", "ability_engulf",
        "weapon_pseudopod", "utility_moss_crown", "ability_coalesce",
        false, false,                     false,
    },
    defaultAction = "weapon_pseudopod",
    -- ITS OWN TWO, and only its own (docs/drops.md): his court called (the Crown) and his death worn (the
    -- Heart) -- both are "what came apart comes back together", handed to the company that beat him.
    drops = { "utility_crown_of_the_court", "utility_moss_heart" },
    -- Walks to his court (AI.POSTURES.gather), which is what puts Coalesce in reach.
    archetype = "gather",
    ai = {
        { priority = "high", act = "cast", item = "ability_engulf",
          when = { subject = "nearest_foe", test = "in_reach" } },
        { priority = "normal", act = "cast", item = "ability_corrosive_touch",
          when = { subject = "nearest_foe", test = "in_reach" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
