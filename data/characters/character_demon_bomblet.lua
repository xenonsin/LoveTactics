-- The Bomblet: a demon bred hollow and filled with fire, and the first self-destruct unit the game
-- fields. It is fast, fragile, and single-minded -- it rushes the nearest body and, when it dies, it
-- BURSTS (data/traits/trait_volatile.lua, carried on the bound data/items/utility/utility_volatile_core.lua).
--
-- IT HAS NO STRIKE. Its only attack is to explode: no bite, no fists (`unarmed = false` leaves it a
-- body that can be moved around the board but can never hit anything -- see models/character.lua). The
-- damage only ever comes from the burst, however the burst is triggered -- the party killing it, an AoE
-- catching it, another Bomblet's blast setting it off, or the bomber pulling its own pin. There is
-- nothing to defend against but its death, which is the whole read.
--
-- It carries that death twice over, and the pair is the design:
--   * data/traits/trait_volatile.lua (on the bound Volatile Core) -- the PASSIVE half. Kill it and it
--     bursts, wherever it happens to be standing.
--   * data/items/ability/ability_self_destruct.lua -- the ACTIVE half. It walks in and pulls the pin
--     itself, over a two-tick channel. Same ring, same 12.
-- Without the second one, a bomb nobody triggers is a bomb the player can walk around and ignore; with
-- it, the Bomblet has a clock. And the channel is what keeps that fair: it wears the channeling badge
-- for a turn first, so stepping one tile clear, shoving it (any knockback breaks a channel) or stunning
-- it all deny the blast outright -- while KILLING it in that window does not, because the trait answers
-- the death with the same burst.
--
-- The lesson it teaches, and the reason it is introduced in the caravan defense
-- (data/encounters/encounter_survivors_defend.lua) one stop before the boss reprises it: DON'T let it
-- die next to you, and don't leave it standing next to you either. Pop it at range (the bow, Fire Bolt,
-- Clear Out) and the blast never reaches you; cut it down in your own teeth and you wear it. Shove it
-- away or into its own kind and the blast is someone else's problem. Kept fragile (one solid hit or any
-- AoE ends it) and low-count so the board reads as a puzzle, not chaos.
--
-- Tuned tight, like the Imp (data/characters/character_demon_imp.lua): ~10 health dies to one iron-bow
-- shot or one Clear Out, so the "kill it at range" answer is always available.
return {
    name = "Bomblet",
    sprite = "assets/chars/demon_bomblet.png",
    revivable = false, -- a demon does not come back (and it bursts on death regardless)
    unarmed = false, -- no natural weapon at all: it cannot strike, only detonate
    stats = {
        health = 10, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0, -- it has no blow to land; the payload is its death
        defense = 1, magicDefense = 1,
        movement = 4, -- it RUSHES: faster on the ground than the party, so it closes the gap
        speed = 2,    -- but slower in the turn order, so the party always gets to answer it first
    },
    -- Two items and one idea. The Volatile Core (bound, center) is not a weapon it swings -- it is the
    -- self-destruct rule (trait_volatile) it goes off with -- and Self-Destruct sits on top of it, the
    -- fuse over the charge. No default action: there is no strike to make one from.
    startingItems = {
        false, "ability_self_destruct", false,
        false, "utility_volatile_core", false,
        false, false,                   false,
    },
    -- Basic tactics (models/ai.lua): the aggressive posture's approach, plus the one rule that matters
    -- -- and that rule rides on Self-Destruct itself rather than being repeated here, so the ability
    -- carries its own tactics wherever it is dropped. It charges the nearest body, and pulls the pin the
    -- moment it can reach one with the blast.
    archetype = "aggressive",
}
