-- The general of Gluttony, and the end of the Hunter's Lodge line (docs/story.md, "The Hunter's Lodge").
-- She holds the wood's last stair (Descent.SINS' gluttony `guardian`).
--
-- WHO SHE IS: once the finest hunter the region ever produced, and the Grand Hunter who TURNED. Every
-- Grand Hunter turns; most turn into a mere beast. Gula made a pact with the Demon Lord and did not merely
-- turn -- she became the APEX of the wood, the one predator every other one in it is prey to. What the
-- bargain gave her was not strength but APPETITE, and an appetite that has eaten everything in a wood can
-- do everything in it.
--
-- SHE IS THE BEAST FROM THE FIRST TURN (2026-09-24). She shipped as two bodies -- a huntress who held one
-- power and lost it to a hard blow, turning at half health into the beast that kept everything -- and the
-- huntress half is cut: the turning happened long before the company reaches her stair, and what stands on
-- it is what the Lodge exists to hunt. The Knock, the one-power cap and her knife went with that half.
--
-- THE REDESIGN (settled on review 2026-09-23, "think Kirby"). Every beast in the circle is known for one
-- thing -- the wyvern carries, the spider roots, the manticore quills, the boar charges -- and Gula EATS a
-- body and takes that thing (models/palate.lua). Her fight is three rules deep:
--
--   * DEVOUR (ability_devour) -- a corpse or a downed body of either side, or any of her OWN side at any
--     time. She heals a tenth and takes its power into her grid.
--   * THE PALATE -- she KEEPS everything she eats; eating a kind she already holds raises that power a
--     forge level, and nothing knocks any of it out. So the fight is a race against the beasts still
--     walking in to feed her.
--   * STUDIED (utility_hunters_read) -- every blow teaches her its damage kind, and the next blow of that
--     kind lands on a body that resists it. One lesson at a time: alternate, and you always land in full.
--
-- AND SHE DRAWS BREATH (ability_the_breath): too slow to walk to her food, she pulls the food to her, and
-- swallows what arrives already beaten -- which is the part of the fight the company can read a turn ahead
-- and answer by leaving the band, standing behind a body, or standing Rooted in the web on purpose.
--
-- AND THE FIGHT IS A WAVE BATTLE: the beasts of the whole floor keep walking in to help her, and every one
-- of them is also food (Descent.SINS' gluttony `guardian.waves`). The win is her body, not the field.
--
-- What she hands over is the Maw of the Unfed (the relic, reworked into the player's half of the Palate),
-- then the Breath and the Hide lifted off her rule -- Descent.DROPS.gluttony.
return {
    name = "Gula, the Unsated",
    race = "beast",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end
    -- of its line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up
    -- from a base -- so a descent that deals this circle as floor 1 meets a smaller version of the
    -- same thing instead of an unkillable one. At this level the numbers below are exactly the
    -- numbers. See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    revivable = false,
    sprite = "assets/chars/general_gluttony.png",
    portrait = "assets/portraits/general_gluttony.png", -- large VN portrait for conversations (falls back if missing)
    archetype = "aggressive",
    eats = true, -- takes the power of what it eats, and keeps all of it (models/palate.lua)
    stats = {
        health = 240, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 22, magicDamage = 0, -- the copies are her threat; her own bite is only a bite
        defense = 13, magicDefense = 5, -- thin against the magic she never learned: bring a caster
        movement = 3, -- slow; the Breath brings you to her
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 3,
    },
    -- What she wears instead of armour (docs/bestiary.md), and a hide is a trade: every beast in the wood has
    -- tried its teeth and claws on it, and not one of them ever brought a club. Fire is the one thing a beast
    -- that never learned magic still fears.
    resist = { slash = 2, pierce = 2, impact = -4, fire = -3 },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Five cells are left open on
    -- purpose: they are where what she eats goes.
    startingItems = {
        "weapon_rending_maw",   "ability_devour", "ability_the_breath",
        "utility_hunters_read", false,            false,
        false,                  false,            false,
    },
    defaultAction = "weapon_rending_maw",
    ai = {
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
