-- The general of Envy, and the end of the Crucible's line (docs/story.md, "The Crucible"). Enemy
-- blueprint; the objective of data/quests/general_envy.lua. The finale (data/quests/the_gate_below.lua)
-- already reserves a slot for her -- "general_envy" sits in its requiredQuests.
--
-- WHO SHE IS: the college's masterpiece homunculus, the one that got far enough to WANT. What she wanted
-- was a self -- to be born, not made. She did not pact for power; she pacted with the Demon Lord for
-- humanity, and the bargain's cruelty is exact: it gave her the power to copy any human perfectly and
-- never once to BE one. She can be anyone and is no one. She is FMA's Envy and the noppera-bo: a hollow
-- thing that wears others' faces and has no face of its own.
--
-- Her rule rides on the Glass in her grid (a blueprint's own `traits` field is never collected; only an
-- item's is -- models/trait.lua): "has no shape until it has seen yours" (data/traits/trait_covetous_reflection.lua)
-- -- at the opening bell she takes the shape of your strongest, and it fights for her. The counterplay is
-- the sin read as tactics: let nothing tower, and she finds a lesser shape to wear. The party Ren
-- flattens upward (character_ren.lua) gives her nothing worth coveting.
--
-- Her kit is her borrowed shape and the blank homunculi she conjures (ability_summon_homunculus). Statted
-- as a hollow thing that fights through what it steals: modest of itself, dangerous through the copy it
-- opens with. `assassinate` is the honest objective.
--
-- TODO (see docs/story.md + the plan): the finale is not fully built. She should be TWO-PHASE -- the
-- borrowed shape sloughs off to reveal the running-quicksilver homunculus underneath -- and her second
-- form brings the Counterfeit Host (blank homunculi that copy a unit only once they SEE it), the Envious
-- Pall, Covet and Grudge. All are new work over what ships here.
return {
    name = "Livia, the Unborn",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_envy.png",
    portrait = "assets/portraits/general_envy.png", -- large VN portrait for conversations (falls back if missing)
    stats = {
        health = 200, mana = 80, stamina = 15,
        staminaRegen = 2,
        damage = 12, magicDamage = 12, -- middling of herself; the copy she opens with is the threat
        defense = 12, magicDefense = 14,
        movement = 4,
        speed = 4,
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Her rule rides on the Envious Glass
    -- in the center (unstealable). Around it: the blank homunculi she fills the board with.
    startingItems = {
        "ability_summon_homunculus", "ability_summon_homunculus", false,
        "weapon_vitriol_wand",       "utility_envious_glass",     false,
        false,                       false,                       false,
    },
    defaultAction = "weapon_vitriol_wand",
    ai = {
        { priority = "high", act = "attack", item = "weapon_vitriol_wand",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
