-- A SWOONCAP PUFFER: the mushroom folk's exploder, and the Lust circle's filler body.
--
-- WHAT THE MUSHROOM FOLK ARE. What comes up out of the pit when nothing is planted in it -- a party of
-- three roles that fight together: a Verger that holds the front, Puffers that walk in and pop, and a
-- Thurifer that casts from behind. They neither root nor shove, so any of them may stand in a fight from
-- either half of the Lust circle, which is exactly the job of the circle's filler (Descent.SINS'
-- `minor.filler`) and the fill its line fights are padded with.
--
-- THE BOMBLET'S RULES WITH A SPORE PAYLOAD. It walks at the nearest body and pops (ability_spore_pop, a
-- channelled burst whose wind-up is the tell), and if it is cut down first it goes off where it stands
-- (trait_spore_burst). Both are poison and Swoon (data/status/status_swoon.lua) on everything beside it,
-- its own folk included -- so shooting one standing among the mushrooms uses its spores on them, and
-- letting it reach the line swoons your front for a turn.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS): low in it, one arrow's worth, because a filler
-- body whose answer is "kill it at range" has to be one you CAN kill at range.
return {
    name = "Swooncap Puffer",
    race = "demon",
    tier = 1,
    sprite = "assets/chars/swooncap_puffer.png",
    revivable = false, -- it bursts; there is nothing left to bring back
    unarmed = false,   -- no blow to land: the payload is the burst
    archetype = "aggressive",
    stats = {
        health = 12, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 1, magicDefense = 2,
        movement = 4, -- it rushes
        speed = 2,    -- but late in the order, so the company gets to answer it
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 3,
    },
    -- INNATE MITIGATION (docs/bestiary.md). A puffball gives under a blow and a point goes straight in;
    -- it is spores all the way through, so poison is its own air. The blood in the pit is Luxuria's.
    resist = { impact = 2, pierce = -2, poison = 2, holy = -2 },
    startingItems = {
        false, "ability_spore_pop", false,
        false, "utility_spore_sac", false,
        false, false,               false,
    },
    drops = {
        "consumable_puffball",
    },
    -- Its one rule rides on Pop itself, as the Bomblet's does on Self-Destruct: it charges the nearest
    -- body and pulls the pin the moment the ring can reach one. Stated here as well, so the tactics
    -- editor shows what it does.
    ai = {
        { priority = "high", act = "cast", item = "ability_spore_pop",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
    },
}
