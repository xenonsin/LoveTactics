-- The Bomblet: a demon bred hollow and filled with fire, and the first self-destruct unit the game
-- fields. It is fast, fragile, and single-minded -- it rushes the nearest body and, when it dies, it
-- BURSTS (data/traits/trait_volatile.lua, carried on the bound data/items/utility/utility_volatile_core.lua).
--
-- IT HAS NO STRIKE. Its only attack is to explode: no bite, no fists (`unarmed = false` leaves it a
-- body that can be moved around the board but can never hit anything -- see models/character.lua), and
-- the one payload it carries goes off when it dies. So on its turn it does exactly one thing -- close
-- the gap -- and the damage only ever comes from the burst, however the burst is triggered: the party
-- killing it, an AoE catching it, or another Bomblet's blast setting it off. There is nothing to defend
-- against but its death, which is the whole read.
--
-- The lesson it teaches, and the reason it is introduced in the caravan defense
-- (data/encounters/encounter_survivors_defend.lua) one stop before the boss reprises it: DON'T let it
-- die next to you. Pop it at range (the bow, Fire Bolt, Clear Out) and the blast never reaches you;
-- cut it down in your own teeth and you wear it. Shove it away or into its own kind and the blast is
-- someone else's problem. Kept fragile (one solid hit or any AoE ends it) and low-count so the board
-- reads as a puzzle, not chaos.
--
-- Tuned tight, like the Imp (data/characters/character_demon_imp.lua): ~10 health dies to one iron-bow
-- shot or one Clear Out, so the "kill it at range" answer is always available.
return {
    name = "Bomblet",
    sprite = "assets/chars/demon_imp.png", -- reuses the imp art until its own exists
    unarmed = false, -- no natural weapon at all: it cannot strike, only detonate
    stats = {
        health = 10, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0, -- it has no blow to land; the payload is its death
        defense = 1, magicDefense = 1,
        movement = 4, -- it RUSHES: faster on the ground than the party, so it closes the gap
        speed = 2,    -- but slower in the turn order, so the party always gets to answer it first
    },
    -- The Volatile Core (bound, center) is all it carries, and it is not a weapon it swings -- it is the
    -- self-destruct rule (trait_volatile) it goes off with. Nothing else, and no default action: there
    -- is no strike to make one from.
    startingItems = {
        false, false,                   false,
        false, "utility_volatile_core", false,
        false, false,                   false,
    },
    -- Basic tactics (models/ai.lua): with nothing to attack WITH, the aggressive posture's approach is
    -- the whole of it -- it charges the nearest body every turn and dies on it. Nothing subtle, and no
    -- attack rule, because it has no attack to name.
    archetype = "aggressive",
}
