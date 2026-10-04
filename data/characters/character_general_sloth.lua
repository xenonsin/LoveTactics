-- DESIDIA, THE DREAMER: the general of Sloth, on floor 10's stair ("Sloth's Bestiary", slice G, 2026-10-04; designed
-- from the circle's brief, every rule approved on review). Enemy blueprint; the objective of the circle's stair.
--
-- A god asleep under the glacier, so large the board is the lid of her tomb. The only part of her above the ice is a
-- 3x3 sleeping face at the far edge of the board. Desidia is Latin for idleness.
--
-- ACEDIA LEFT THIS ID. The Unrelieved -- the knight who negotiated her post away -- held it until the author removed
-- her; the id stays because the stair, the Many Faced One's forms, the Hollow Crown and the scene name it. Her pike
-- and the Bastion pieces that queued behind it stay on disk. The descent's scene still speaks in Acedia's voice
-- (data/conversations/descent/conversation_descent_sloth.lua), which is the author's to rewrite.
--
-- A GIANT, the Titan's record (data/races/giant.lua): a body built on the scale of the old wars, humanoid in shape,
-- with nothing granted -- the record a god's prisoner already stands on, and the honest bucket for something whose
-- face alone fills nine tiles. Not a demon: nothing about a sleep burns.
--
-- HER RULES ride on three organs (a blueprint's own `traits` field is never collected), and models/desidia.lua argues
-- them in full: the Long Sleep (Dormant, a turn banked a round, Stir from every attack and ability on the board, and
-- at 10 every banked turn at once, each a sweep down a marked row), the Drowse (whoever took a turn and did not move
-- gains Drowsy), What the Sleepers Dream (a sleeping foe's nightmare stands up on her side) and her phase two (awake
-- and spent, any round with no blow on her puts her back to sleep, banking from zero).
--
-- SHE NEVER MOVES (`movement = 0`, and the Dreamer is `unmoved`): the face is the top of a body under the ice. Awake,
-- she breathes on whoever is in reach of it; her real weight is the bank. 300 health on nine tiles, struck from
-- beside any of them -- a company that keeps hitting her is the company keeping her awake, which is the decision.
return {
    name = "Desidia, the Dreamer",
    race = "giant",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end
    -- of its line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up
    -- from a base -- so a descent that deals this circle as floor 1 meets a smaller version of the
    -- same thing instead of an unkillable one. At this level the numbers below are exactly the
    -- numbers. See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_sloth.png",
    portrait = "assets/portraits/general_sloth.png", -- large VN portrait for conversations (falls back if missing)
    -- NINE TILES: the face above the ice, seated at the far edge as the fight opens (Desidia.seat).
    footprint = { w = 3, h = 3 },
    stats = {
        health = 300, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 16, magicDamage = 14,
        defense = 10, magicDefense = 10,
        movement = 0, -- she does not move; the glacier is the rest of her
        speed = 3,
        skill = 4, luck = 2,
    },
    startingItems = {
        false, "weapon_desidias_breath", false,
        "utility_the_dreamer", "utility_the_drowse", "utility_what_the_sleepers_dream",
        false, false, false,
    },
    -- Her fall pays her own pieces (Descent.DROPS.sloth.general pays the same list, relic first).
    drops = { "utility_the_long_sleep", "ability_lull", "utility_nightmare_lantern", "armor_restless_mail" },
    defaultAction = "weapon_desidias_breath",
    archetype = "defensive",
}
