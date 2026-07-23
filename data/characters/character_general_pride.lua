-- The general of Pride, and the end of the Arcanum's line (docs/story.md, "The Arcanum"). Enemy
-- blueprint; the objective of data/quests/general_pride.lua. The finale (data/quests/the_gate_below.lua)
-- already reserves a slot for her -- "general_pride" sits in its requiredQuests.
--
-- WHO SHE IS: a human who made a pact with the Demon Lord for perfect comprehension -- she has only to
-- glance at a working to know it and cast it herself -- and became the greatest mage of the age, and
-- certain of it. Perfection is a ceiling: she can admit no wrong, can hear no objection, and will do
-- anything to keep the summit. She is Aura's pride (Frieren): she measures every mage by what they SHOW
-- her, and is sure the scale falls her way.
--
-- Her rule rides on the codex in her grid (a blueprint's own `traits` field is never collected; only an
-- item's is -- models/trait.lua): "answers every spell with your own" (data/traits/trait_perfect_recall.lua)
-- -- a single-target spell aimed at her is answered and unravelled, because she already knows it. The
-- counterplay is the sin read as tactics: do not show her your hand; win with what she cannot answer. The
-- one mage she can never measure is Gyeom (character_gyeom.lua), who shows nothing worth taking.
--
-- Her kit is her own, and devastating: a downpour that catches a whole cluster (ability_rain), a bolt
-- (ability_fire_bolt), NECROMANCY that raises the fallen to her side (ability_raise_dead), and a DOUBLE of
-- herself on the field (ability_doppelganger -- Pride's answer to every problem is another of her). Statted
-- as a true powerhouse rather than a wall: high magic, warded against magic, a deep mana pool to answer and
-- cast from. `assassinate` is the honest objective -- her guard is a wall to pass, not a thing to grind.
--
-- TODO (see docs/story.md + the plan): the finale kit is not fully built. Her rule ships as a counter-magic
-- reflex; the full "glance and cast it BACK" mirror is deferred. The fight should also be TWO-PHASE -- the
-- human Archmage sheds into a demon who fills the board with copies of herself (the shipped doppelganger
-- writ large) -- and her necromancy should raise ANY fallen, yours or hers. Both are new work over what
-- ships here.
--
-- Her codex carries her rule for whoever lifts it (data/items/utility/utility_codex_unanswered.lua).
return {
    name = "Sublimitas, the Unequalled",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_pride.png",
    portrait = "assets/portraits/general_pride.png", -- large VN portrait for conversations (falls back if missing)
    stats = {
        health = 210, mana = 90, stamina = 15,
        staminaRegen = 2,
        damage = 9, magicDamage = 18, -- the greatest mage of the age; her spells are the threat
        defense = 14, magicDefense = 20, -- warded against the magic her line traffics in
        movement = 4,
        speed = 4,
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Her rule rides on the Codex
    -- Unanswered in the center (bound to her by the relic, unstealable). Around it: her own catastrophe and
    -- necromancy, and the double she splits into.
    startingItems = {
        "ability_rain",  "ability_doppelganger",      "ability_raise_dead",
        "weapon_wand",   "utility_codex_unanswered",  "ability_fire_bolt",
        false,           false,                        false,
    },
}
