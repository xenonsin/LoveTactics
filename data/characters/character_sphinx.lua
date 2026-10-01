-- THE SPHINX: one of Pride's one-off elites, on the spire's approach ("Pride's Bestiary", 2026-09-30). It is
-- never wrong.
--
--   THE RIDDLE   when the fight opens and at the end of each of its turns, it asks the company one of five
--                riddles -- strike with fire, none of you moves, exactly one of you attacks, strike from three
--                tiles away, two of you strike the same foe -- dealt off the fight's own seed, never the same
--                one twice running (trait_the_riddle, on its organ; models/pride_elites.lua)
--   UNANSWERED   it takes no damage at all (Status.immuneToDamage)
--   MET          a round that meets it leaves it Answered: open to damage until its next turn ends
--   FAILED       a round that fails it heals it 10%
--
-- THE COUNTERPLAY, STATED: read the badge, answer the riddle, and hit it in the window you bought. A company that
-- ignores it fights a body that cannot be hurt and grows back. Sundered, it asks and wards nothing.
--
-- ALONE (encounter_pride_the_sphinx): the riddle is the whole fight, and an escort would turn half the riddles
-- ("two of you strike the same foe") into questions about somebody else. Its lion's hide takes a blow and lets a
-- point in. Tier 3 and `boss`.
return {
    name = "Sphinx",
    race = "beast",
    tier = 3,
    boss = true,
    sprite = "assets/chars/sphinx.png",
    stats = {
        health = 130, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 15, magicDamage = 0,
        defense = 8, magicDefense = 8,
        movement = 4,
        speed = 4,
        skill = 8, luck = 4,
    },
    resist = { impact = 2, pierce = -2 },
    startingItems = {
        false,              false,                false,
        "weapon_lions_paw", "utility_the_riddle", false,
        false,              false,                false,
    },
    defaultAction = "weapon_lions_paw",
    -- ITS OWN PIECE (docs/drops.md): the riddle, asked of your own side.
    drops = { "utility_sphinxs_riddle" },
    archetype = "aggressive",
}
