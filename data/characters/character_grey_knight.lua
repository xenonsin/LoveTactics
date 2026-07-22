-- The human standing at Highwatch's gate on the demons' side of it (data/quests/relief_column.lua,
-- slot 1 of the Bastion's ten). He is one of Acedia's company -- mechanically a
-- character_forsworn_knight in everything but posture and nameplate -- and the player is not
-- supposed to know that for another three quests.
--
-- WHY A SEPARATE BLUEPRINT, on both counts:
--
--   The name. Unit nameplates are on the board, so spawning "Forsworn Knight" here would hand the
--   player the word the entire line is built on, at the line's front door, before Rowan has said
--   Acedia's name twice. "Knight in Grey" is what a stranger actually sees: a man in a knightly
--   order's forms, no colours anyone can place, fighting beside demons and not explaining himself.
--   The word `forsworn` should first reach the player at slot 4, out of a captain's own mouth.
--
--   The leash. `guard` (leash 4) instead of the forsworn knight's default aggression. His statline
--   is built for the prestige-3+ encounters and slot 1 runs at prestige 1 beside an 84hp Breachward,
--   so an aggressive one turns the introduction into the hardest board in the early game. Leashed,
--   he holds the gate: unmistakably present, unmistakably not demon rabble, and the player chooses
--   whether to open that fight or go around him for the mark. Present, not pivotal.
--
-- Nobody remarks on him. No scene mentions him. The gap is the content -- see the composition
-- comment in data/quests/relief_column.lua.
return {
    name = "Knight in Grey",
    sprite = "assets/chars/forsworn_knight.png",
    class = "knight",
    archetype = "guard",
    stats = {
        health = 62, mana = 0, stamina = 13,
        staminaRegen = 2,
        damage = 15, magicDamage = 0,
        defense = 14, magicDefense = 6,
        movement = 3,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_spear", "armor_chainmail", false,
        false,               false,             false,
        false,               false,             false,
    },
    defaultAction = "weapon_iron_spear",
    -- Basic tactics (models/ai.lua): a spearman charges a line. Held by his `guard` leash, he still
    -- presses when two or more foes crowd into reach and lets the scorer find the skewer.
    ai = {
        { priority = "high", act = "attack", when = { subject = "any_foe", test = "count_at_least", value = 2 } },
    },
}
