-- SUBLIMITAS, THE UNEQUALLED: Pride's lieutenant, on the spire's first stair (moved down 2026-10-01, when the
-- general's seat went to Superbia, the Morning Star). The end of the Arcanum's line (docs/story.md, "The
-- Arcanum").
--
-- WHO SHE IS: an elf, and the greatest mage of the age. She made a pact with Superbia for perfect comprehension
-- -- she has only to see a working to know it -- and serves the Morning Star for it now. Perfection is a ceiling:
-- she can admit no wrong and hear no objection. She is Aura's pride (Frieren): she measures every mage by what
-- they SHOW her, and is sure the scale falls her way. As an elf she opens Unblemished (data/races/elf.lua), so
-- the first wound is worth more against her than any other.
--
-- HER RULE rides on her organ (utility_already_known; a blueprint's own `traits` field is never collected):
-- every spell cast in her sight, by anyone, becomes Known, and a Known spell aimed at her is unravelled. A spell
-- she has not seen lands in full and is Known after. A sword is never learned. Show her each spell once.
--
-- HER KIT: a downpour for a cluster (ability_rain), a bolt (ability_fire_bolt), necromancy that raises the
-- fallen to her side (ability_raise_dead), a double of herself that dies to a single hit (ability_doppelganger --
-- Pride's answer to every problem is another of her), and her wand.
--
-- SIZED AS A LIEUTENANT, not a general: tier 3, the band tests/pride_circle_spec.lua holds a Pride stair body to
-- (over the gilded sworn, 60-85% of the general). `referenceLevel` like every stair centrepiece, so the numbers
-- below are her numbers on her own floor and a shallower meeting is a smaller her.
--
-- HER DROP is the Codex Unanswered, a Mage's trophy carrying the same rule (Descent.DROPS lists it first).
return {
    name = "Sublimitas, the Unequalled",
    race = "elf",
    class = "mage",
    tier = 3,
    referenceLevel = 13,
    boss = true, -- the stair's fight: off the execute and Charm tables
    sprite = "assets/chars/sublimitas.png",
    portrait = "assets/portraits/sublimitas.png", -- large VN portrait for conversations (falls back if missing)
    archetype = "skirmish",
    stats = {
        health = 150, mana = 110, stamina = 15, -- 62.5% of the Morning Star's 240 (tests/pride_circle_spec.lua), inside tier 3
        staminaRegen = 2,
        damage = 7, magicDamage = 15, -- Unblemished lifts both by 4 until she is first wounded
        defense = 5, magicDefense = 14,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): her race adds 2 to skill, so she aims at 10 -- the Unequalled's number.
        skill = 8, luck = 3,
    },
    -- Her rule in the centre, bound; around it her catastrophe, her necromancy, her double and her bolt.
    startingItems = {
        "ability_rain",  "ability_doppelganger",   "ability_raise_dead",
        "weapon_wand",   "utility_already_known",  "ability_fire_bolt",
        false,           false,                     false,
    },
    -- Her trophy first; the coordinator's Descent.DROPS pays the same list on her stair.
    drops = { "utility_codex_unanswered", "utility_marginal_gloss" },
    defaultAction = "ability_fire_bolt",
    signatureWeapon = "weapon_wand",
}
