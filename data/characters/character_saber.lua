-- Saber, the fighter companion (patience) -- the second recruit and the boss of the first Colosseum
-- bout (data/quests/arena_debut.lua). See docs/story.md, "The other seven": every companion is a
-- woman with a gender-neutral name, and the virtue is hinted, never labeled -- a saber is her blade,
-- and in another tongue (sabr) it is patience itself.
--
-- Her patience wears the face of JOY. A free agent of the sand -- no house, no program, belonging to
-- no one -- she loves fighting for its own sake, so she is never in a hurry: there is nowhere she would
-- rather be than mid-bout, which is why she can hold the swing, never gets greedy, and opens the same
-- card for years without souring. That is contentment, not endurance -- and it is the exact pole
-- opposite Ira (see character_general_wrath.lua): the foil is FREEDOM vs. BONDAGE. Saber fights because
-- she is free and stays by choice; Ira fought because the sand was the only place she was ever free,
-- and now cannot walk off it at all. Saber already has enough, every fight, and can walk off any time.
--
-- She is the arena's gatekeeper, and the debut bout is secretly her own audition: a seasoned
-- gladiator who has watched the Colosseum and its patron, Ira, devour fighter after fighter, and who
-- will not be eaten. She fights every newcomer waiting for the pair who can beat her. She was never in
-- the Perennial's program; her tie to the patron beneath the sand is SYMPATHY, not rivalry -- a free
-- fighter looking at a caged one -- and freeing Ira the only way left is the whole wrath line. Beat her
-- and she joins; the fighter you best in sport here is the foil to the general you free in earnest at
-- the line's end.
--
-- THIS is the recruit -- the companion the player keeps. The bout that introduces her is fought by a
-- boss TWIN (data/characters/character_saber_bout.lua) which extends this file with the boss flag, a
-- deeper health pool and the phase relic; the quest recruits THIS blueprint, so none of that rides
-- home. She is no longer `boss = true` herself: an ally is never targeted by execute or Charm, so the
-- flag only ever meant anything on the version being fought, and now lives there. Her kit is
-- burst-and-finish -- the greatsword's raw damage -- which is exactly the counterplay to Ira, whose
-- rule rewards a long trade. A potion beside it keeps her patient: she does not have to win fast.
return {
    name = "Saber",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/saber.png",
    portrait = "assets/portraits/saber.png", -- large VN portrait for conversations (falls back if missing)
    class = "fighter",
    overworldAbility = "held_swing", -- patience: steps since her last fight bank into her next opening
    -- Above the fighter base (character_fighter.lua) on the physical side -- she is tier 3 and the
    -- greatsword's own body -- and EXACTLY the base on the magic side, which is the companion
    -- convention (Rowan holds the knight base's 15/4 untouched). The magic side used to read 0/0, and
    -- zero is not "she is martial", it is an EQUIP GATE: class never gates gear (docs/classes.md --
    -- anyone can carry anything), so an empty pool silently made every mana-costed item in the game
    -- unusable on her, and the sheet printed two dead rows to say so. Nothing in her kit spends mana
    -- (First Motion and the bolas are stamina, which is what the 20/+2 is for), and the fighter growth
    -- table grows neither mana nor magicDamage -- so this is a starting floor she never climbs, the same
    -- token pool every other fighter walks around with.
    stats = {
        health = 84, mana = 5, stamina = 20,
        staminaRegen = 2,
        damage = 22, magicDamage = 3,
        defense = 11, magicDefense = 6,
        movement = 4,
        speed = 4, -- quick for a greatsword: she picks her moment
    },
    -- The First Motion is the build-around, `bound` in the centre exactly as Rowan's Aegis is
    -- (data/items/weapon/weapon_first_motion.lua). It is the counterplay to Ira stated as arithmetic:
    -- Ira scales as her own health falls, Saber scales with her target's. A player who fields Saber
    -- has been holding the answer to the general since the debut bout.
    startingItems = {
        false,           "consumable_healing_potion", false,
        "ability_bolas", "weapon_first_motion",       false,
        false,           false,                       false,
    },
    defaultAction = "weapon_first_motion",
    ai = {
        -- Basic tactics (models/ai.lua), top-to-bottom, first match wins. Every swing is the same
        -- greatsword; what separates the rules is WHO she goes for and HOW LONG SHE HOLDS IT, which is
        -- the whole of the weapon.
        --
        -- 1. ROOTED -- pinned by a trapper's bolas (character_trapper), or her own. She
        -- PRIORITIZES a pinned foe: a rooted body cannot walk out at all, so it is the surest mark on
        -- the board. But the root is only six ticks, so a deep hold would resolve AFTER it lapses (her
        -- turn comes back at +4, and +5 more of wind-up lands at 9) -- she takes the SNAP that lands
        -- inside the pin. Reliable damage on something that cannot dodge, and the snap still lays her
        -- sand under it, setting up rule 2. She is patient, not greedy: she picks a moment she can keep.
        { priority = "high", act = "attack", item = "weapon_first_motion", windup = 2,
          when = { subject = "any_foe", test = "has_status", value = "status_root" } },
        -- 2. COWERING -- caught flinching under her last telegraph (data/status/cowering.lua). A cowering
        -- body moves too few tiles to clear a deep cone before the blow falls, so this is the one line
        -- that can afford to hold the edge to the cap. Self-bootstrapping: a snap swing cows whoever is
        -- under it, and THEN she can commit to the deep hold on a foe that can no longer stroll clear.
        -- The fight escalates because of what she already did, not because a timer said so.
        { priority = "high", act = "attack", item = "weapon_first_motion", windup = 5,
          when = { subject = "any_foe", test = "has_status", value = "status_cowering" } },
        -- 3. Nothing holding them yet: throw the bolas herself. Reached only when the two rules above
        -- missed, so first-match-wins does the "is this foe already pinned or bogged?" test for free,
        -- with no negation to author. This is also her fast action -- speed 4 against the greatsword's
        -- committed swing -- so a turn she cannot profitably swing on is never an empty one.
        { priority = "normal", act = "cast", item = "ability_bolas",
          when = { subject = "any_foe", test = "within", value = 3 } },
        -- 4. Otherwise SNAP the greatsword. Her damage climbs with the target's remaining health, so
        -- the scorer already points her at the freshest foe on its own; the shallow hold is what stops
        -- her telegraphing a blow the target can simply stroll out of -- and it lays the sand, which is
        -- what sets rule 2 up.
        { priority = "normal", act = "attack", item = "weapon_first_motion", windup = 2,
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
