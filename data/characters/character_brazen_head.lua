-- THE BRAZEN HEAD: one of Envy's one-off families, the seat's elite ("Envy's Bestiary", 2026-10-03, slice C). Friar
-- Bacon's head of brass, which speaks three times -- and in the old story nobody was awake to hear it.
--
--   TIME IS       a wind-up; when it lands, every body on its side is Hasted
--   TIME WAS      a wind-up; every body on its side heals what it lost since the last utterance
--   TIME IS PAST  a wind-up; the head shatters, and every foe within 3 is Stunned
--
-- Every utterance is a channel, and a shove breaks it like every channel: the head then says the same thing again
-- (models/envy_seat.lua keeps the order). It speaks and does nothing else (AI.preempt), and it cannot walk.
--
-- THE COUNTERPLAY, STATED: shove it to break each wind-up, and burst its guards between the first and second
-- utterances, before Time Was undoes the work. It fights behind a guard and two Homunculi
-- (encounter_envy_the_brazen_head).
--
-- A construct of brass: an edge rings off it and a hammer dents it.
return {
    name = "Brazen Head",
    race = "construct",
    tier = 3,
    sprite = "assets/chars/brazen_head.png",
    stats = {
        health = 90, mana = 0, stamina = 0,
        staminaRegen = 0,
        damage = 0, magicDamage = 8,
        defense = 7, magicDefense = 7,
        movement = 0,
        speed = 4,
        skill = 4, luck = 0,
    },
    resist = { slash = 3, impact = -3 },
    startingItems = {
        "ability_time_is_spoken", "ability_time_was_spoken", "ability_time_is_past_spoken",
        false,                    "utility_brazen_voice",    false,
        false,                    false,                     false,
    },
    defaultAction = "ability_time_is_spoken",
    -- BOTH drops the author took from round 2 (options A and B): the second utterance as a Theurge's rewind, the
    -- third as an Artificer's last word.
    drops = { "ability_time_was", "utility_time_is_past" },
    archetype = "defensive",
}
