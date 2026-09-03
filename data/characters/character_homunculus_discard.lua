-- The thing in the crate. A homunculus that came out hollow -- eyes sewn shut, written off and
-- written down as stock -- and the body a `protect` objective is pointed at in slot 1 of the
-- Crucible's line (data/quests/alchemist/quest_alchemist_slot_01.lua) and again in the shelter
-- raid at slot 8.
--
-- IT IS A SEPARATE BLUEPRINT FROM character_homunculus, AND THAT IS THE POINT. The two are the same
-- creature and opposite units. `character_homunculus` is a COMBATANT three ways over -- the
-- Alchemist's summon (ability_summon_homunculus), the Crucible's rank-and-file in seven other slots,
-- and in both roles its worth is the Poison its fists leave behind, so it must walk up to something
-- and hit it. This one is CARGO. It stands where it is put, it is what the quest is lost on, and a
-- charge posture on the body you are protecting is a loss condition that kills itself on turn two.
-- One blueprint cannot hold both postures, so it does not try.
--
-- `archetype = "holdGround"` (models/ai.lua) roots it on its tile: it swings the default unarmed
-- fist only at whatever is already on top of it and lets everything else walk past. Same call
-- data/characters/character_survivor.lua makes, for the same reason.
--
-- Tougher than a survivor and much tougher than the summon it is cut from, because it is a LOSS
-- CONDITION rather than a clock. It is grown to the enemy's level like any escort (states/battle.lua),
-- and slot 1 opens the line against a bandit chief who reads as an execution to anything the summon's
-- 18 health could put on the board -- a charge the player loses before they have understood they were
-- given one is not a difficulty, it is a bug. It still cannot save itself, and a pack that gets past
-- the party still ends it; the player just has turns in which to be the answer.
--
-- The name on the board is the college's word for it, not the truth. Nobody in slot 1 says the true
-- sentence out loud and the unit label must not either -- see the quest's header.
--
-- Art: its own sheet, and its own silhouette (`delapouite/blindfold`, tools/char_compose.lua). It may
-- not ride the homunculus's picture -- a player who cannot tell the charge from the stock cannot be
-- asked to keep it alive.
return {
    name = "Reagent",
    kind = "construct",
    tier = 0,
    archetype = "holdGround",
    sprite = "assets/chars/homunculus_discard.png",
    stats = {
        health = 46, mana = 0, stamina = 5,
        staminaRegen = 1,
        damage = 0, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 2,
        speed = 2,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 0,
    },
}
