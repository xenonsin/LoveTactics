-- A Mimic: the chest that was never a chest, and the one body in the game whose kit is not authored.
--
-- WHAT MAKES IT DIFFERENT FROM EVERY OTHER ELITE is the grid below, which is nearly empty and is
-- supposed to be. A mimic fights with WHAT IT SWALLOWED -- the exact contents of the chest it has been
-- pretending to be -- folded into its grid when the fight is built and paid out to the company that
-- kills it (models/mimic.lua). So the fight is different every time in the only way that matters: the
-- thing you are about to be hit with is the thing you walked over there to pick up.
--
-- ITS COUSIN IS THE COFFER-CRAWLER (data/characters/character_coffer_crawler.lua), and the pair is
-- deliberate: Greed's line body is armoured in what it has swallowed and this is what happens when the
-- same idea learns to stay still. They are told apart where a player can feel it -- the crawler is a
-- bag of loose metal that rings under a hammer, and this is a lid full of teeth that a spear does
-- nothing to, because there is nothing inside it to stab.
--
-- ...AND THE BESTIARY'S RULE IS NOT BEING BROKEN HERE, though it looks like it at a glance. "Creature
-- chaff carry natural weapons only, and NEVER a discipline item" (docs/bestiary.md) is a rule about
-- what a body IS: a wolf is not a Beastmaster. This blueprint carries exactly one natural weapon and
-- claims no class and no discipline, which is the rule held. What arrives in the other eight cells at
-- runtime is CARGO -- somebody else's axe, in a box -- and the box has not learned to be a Warlord by
-- swallowing one. tests/bestiary_spec.lua reads the blueprint, which is the right thing for it to read.
--
-- NOT A `boss`. It is immune to nothing: Coup de Grace fells it and a Charm turns it, and both of those
-- are answers a company can actually bring to a fight it did not choose to start. A body that ambushes
-- you AND is off the execute table would be a stop with no counterplay in it.
--
-- ALONE, ALWAYS (data/encounters/encounter_mimic.lua fields a cast of one). A second mimic is a second
-- chest, standing somewhere else on the floor.
return {
    name = "Mimic",
    race = "construct",
    tier = 3,
    sprite = "assets/chars/mimic.png",
    stats = {
        health = 112, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 15, magicDamage = 0,
        -- Timber and iron banding. The mind is the part that is missing, so a spell goes straight
        -- through the disguise -- which is the counterplay a party that brought a caster already owns.
        defense = 9, magicDefense = 3,
        -- It does not chase well. A chest with legs is answered the way a big animal is answered: back
        -- off it and make it walk. What it is NOT is slow to act -- it has been waiting.
        movement = 3,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 2,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   A blade skids off banded oak, and a point finds nothing behind the lid worth finding.
    --   It is still a box, and a box is opened by breaking it -- which is what pays for the other two.
    resist = { slash = 3, pierce = 4, impact = -7 },
    -- ONE ITEM, AND THE EMPTY CELLS ARE THE FEATURE. See the header: models/mimic.lua fills the rest
    -- with the chest's contents at the moment the fight is built, and tests/mimic_spec.lua pins that
    -- there is room left for them.
    startingItems = { "weapon_mimic_bite" },
    defaultAction = "weapon_mimic_bite",
    -- Basic tactics (models/ai.lua). NO `item` named on the rule, and that is the whole wiring: a rule
    -- that names an item is about that item alone, and a rule that names none considers the WHOLE KIT
    -- -- so the axe that came out of the chest is picked up and swung without this blueprint ever
    -- learning there was an axe.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
