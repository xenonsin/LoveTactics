-- Saber, the fighter companion (patience) -- the second recruit and the boss of the first Colosseum
-- bout (data/quests/arena_debut.lua). See docs/story.md, "The other seven": every companion is a
-- woman with a gender-neutral name, and the virtue is hinted, never labeled -- a saber is her blade,
-- and in another tongue (sabr) it is patience itself.
--
-- She is the arena's gatekeeper, and the debut bout is secretly her own audition: a seasoned
-- gladiator who has watched the Colosseum and its patron, Ira (see character_general_wrath.lua),
-- devour fighter after fighter, and who will not be eaten. She fights every newcomer waiting for the
-- pair who can beat her -- and her quarrel with the patron beneath the sand is the whole wrath line.
-- Beat her and she joins; the fighter you best in sport here is the foil to the general you kill in
-- earnest at the line's end.
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
    sprite = "assets/chars/saber.png",
    portrait = "assets/portraits/saber.png", -- large VN portrait for conversations (falls back if missing)
    class = "fighter",
    stats = {
        health = 84, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 22, magicDamage = 0,
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
        -- Basic tactics (models/ai.lua), top-to-bottom, first match wins. Both rules swing the same
        -- greatsword; what separates them is HOW LONG SHE HOLDS IT, which is the whole of the weapon.
        --
        -- 1. MIRED -- standing in the sand her own last swing churned up. This is the only line that
        -- pays off the deep end of `windup`, and it is self-bootstrapping: a snap swing lays the
        -- quicksand (weapon_first_motion's channelHazard), the sand doubles what a step costs, and
        -- THEN she can afford to hold the edge to the cap because leaving is no longer cheap. The
        -- fight escalates because of what she already did, not because a timer said so.
        { priority = "high", act = "attack", item = "weapon_first_motion", windup = 5,
          when = { subject = "any_foe", test = "has_status", value = "status_mired" } },
        -- 2. ROOTED -- pinned by her own bolas, but only for six ticks. A deep hold would resolve
        -- AFTER the root lapses (her turn comes back at +4, and +5 more of wind-up lands at 9), so
        -- she takes the snap that lands inside it. She is patient, not greedy: the whole discipline
        -- is picking a moment you can actually keep.
        { priority = "high", act = "attack", item = "weapon_first_motion", windup = 2,
          when = { subject = "any_foe", test = "has_status", value = "status_root" } },
        -- 3. Nothing holding them yet: throw the bolas. Reached only when the two rules above missed,
        -- so first-match-wins does the "is this foe already pinned?" test for free, with no negation
        -- to author. This is also her fast action -- speed 4 against the greatsword's committed swing
        -- -- so a turn she cannot profitably swing on is never an empty one.
        { priority = "normal", act = "cast", item = "ability_bolas",
          when = { subject = "any_foe", test = "within", value = 3 } },
        -- 4. Otherwise SNAP the greatsword. Her damage climbs with the target's remaining health, so
        -- the scorer already points her at the freshest foe on its own; the shallow hold is what stops
        -- her telegraphing a blow the target can simply stroll out of -- and it still lays the sand,
        -- which is what sets rule 1 up.
        { priority = "normal", act = "attack", item = "weapon_first_motion", windup = 2,
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
