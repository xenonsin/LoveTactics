-- THE HOLLOW CROWN: the First Archon, at the bottom of the rift, and the end of everything the seven ladders were
-- counting toward ("The Crown's Bestiary", slice D, approved over rounds 3-4 of the review page). Enemy blueprint; the
-- objective of the fifteenth floor's stair (models/descent.lua's crownComposition).
--
-- The seven wants were all its own, and seven people carried them off: the generals the company killed on the way
-- down. What sits on the throne is hollow. It has no sin left, so it does what a hollow thing does: it reaches for the
-- rules the company already beat, one floor at a time, and then for the company itself. A 3x3 throne at the far edge
-- of the board for phases 1 and 2, then a 1x1 body that walks. Every phase asks for a lesson the game already taught,
-- so the fight is the exam and not a new set of rules (models/hollow_crown.lua; its organ carries the four phases).
--
-- AN ARCHON, NOT A DEMON. It was `race = "demon"` and wore utility_demonic_essence, so holy cut it the harder and
-- Demon Bane was said to be forged for it. The author made it the first of the court it sits behind, and an Archon
-- has no holy line: the weakness came off with the essence (the item stays on disk). The race hands it Spirit Body
-- like every Archon, which it never spends: `revivable = false` leaves no downed body for a wisp to tear loose from.
--
-- THE ID IS OLD. `character_demon_lord` is what the stair, the scene and the breach name, so the body kept it.
return {
    name = "The Hollow Crown",
    race = "archon",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end
    -- of its line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up
    -- from a base -- so a descent that deals this circle as floor 1 meets a smaller version of the
    -- same thing instead of an unkillable one. At this level the numbers below are exactly the
    -- numbers. See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/demon_lord.png",
    revivable = false, -- the last fight ends on its body: no downed window, and so no wisp
    -- NINE TILES for phases 1 and 2: the throne, seated at the far edge (Desidia.seat) and Enthroned. At half health
    -- it shrinks to the centre tile and walks (HollowCrown.stand).
    footprint = { w = 3, h = 3 },
    stats = {
        health = 462, mana = 48, stamina = 25,
        manaRegen = 4,
        damage = 20, magicDamage = 20,
        defense = 5, magicDefense = 12, -- 14 after the race
        movement = 4, -- held by Enthroned until it steps down
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Grown plate over the whole of it, and there is no edge in the game that opens it.
    --   Weight opens it.
    resist = { slash = 5, impact = -5 },
    -- Its loadout as the 3x3 grid (row-major); false = an empty cell. Its rule rides on its organ in the centre
    -- (utility_the_first_archon, bound, so a rogue can never lift the fight off it). The court's own arms are all it
    -- carries: the mana-cut blade every Archon swings, and the Ascended Duke's Sentence for the throne's reach.
    startingItems = {
        false,                   "ability_sentence_of_the_court", false,
        "weapon_mana_cut_blade", "utility_the_first_archon",      false,
        false,                   false,                           false,
    },
    -- Its fall pays its own pieces (Descent.DROPS.crown pays the same list, the relic first).
    drops = {
        "armor_hollow_crown", "utility_omen", "ability_the_floor_gives_way", "utility_usurper",
        "utility_crown_of_thorns",
    },
    defaultAction = "weapon_mana_cut_blade",
    signatureWeapon = "weapon_mana_cut_blade",
    -- Basic tactics (models/ai.lua): once it walks, it hunts the body with the fewest open tiles around it --
    -- the one the Pit has hemmed in.
    ai = {
        { priority = "high", act = "attack", targetPref = "hemmed",
          when = { subject = "any_foe", test = "exists" } },
    },
}
