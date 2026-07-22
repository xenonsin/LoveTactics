-- Kaya, the hunter companion (temperance), and the answer to Gluttony at the head of the Hunter's Lodge
-- line (docs/story.md, "The Hunter's Lodge"). A woman, a gender-neutral name, the virtue buried and not
-- stamped: Kaya is Arabic kifaya -- sufficiency, "it is enough" -- the way Saber's name is patience and
-- Amana's is a trust (character_saber.lua, character_amana.lua). The models are Golden Kamuy's Asirpa and
-- Mononoke's San, who runs with wolves as Kaya runs with the one on her horn.
--
-- THE ANSWER TO THE GENERAL SHE FACES, but not her kin. Gula (character_general_gluttony.lua) is a Grand
-- Hunter who hunted the sacred past need and became the beast; Kaya is the hunter who never took past
-- need and so the wild never turned on her. Same craft, opposite answer: gluttony never stops,
-- temperance is the hunt that knows when to stop. She is the one hunter the curse can never claim -- proof
-- the beast is a choice, not a fate.
--
-- SHE IS RECRUITED AS A GUIDE, NOT A KILL. Unlike Amana or Saber she is never a boss objective: the
-- Lodge's board pushes the player deeper than any outsider can go, and Kaya and her wolf turn back the
-- wild that would swallow them, then she agrees to lead them to the beast at the wood's heart
-- (data/quests/the_guide.lua). So no `boss = true`: nothing ever fights her.
--
-- HER KIT IS TEMPERANCE MADE MECHANICAL, built around the Wolfsong Horn in the center
-- (data/items/utility/utility_wolfsong_horn.lua, already forged): a wolf fields itself at her side at the
-- first bell (data/traits/trait_wolf_companion.lua), and while it lives the horn's Quieting Howl ROOTS
-- the ring around her or the wolf -- "the hunt that knows when to stop" turned on the enemy. Read as
-- tactics against Gula: root the ring, break the long trade, and a heal-on-hit foe is starved rather
-- than fed.
--
-- TODO (see docs/story.md): the temperance-immunity fold-in -- Gula's hunger finding no purchase on Kaya
-- because there is nothing on her to eat -- is deferred with the general's devour mechanic it answers.
return {
    name = "Kaya",
    sprite = "assets/chars/kaya.png",
    portrait = "assets/portraits/kaya.png", -- large VN portrait for conversations (falls back if missing)
    class = "hunter",
    stats = {
        health = 66, mana = 20, stamina = 60,
        staminaRegen = 2,
        damage = 16, magicDamage = 0, -- a clean shot, and no more than the shot needs
        defense = 8, magicDefense = 8,
        movement = 4, -- she covers ground; the wild is hers
        speed = 5,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Wolfsong Horn is the build-around in
    -- the center; a longbow to keep the distance a kiter needs, and a potion for the long night in the wood.
    startingItems = {
        "weapon_iron_longbow", "ability_pinning_shot",  "consumable_healing_potion",
        false,                 "utility_wolfsong_horn", false,
        false,                 false,                   false,
    },
    defaultAction = "weapon_iron_longbow",
    ai = {
        -- Basic tactics (models/ai.lua): loose the bow at whatever is in reach; the horn and wolf carry
        -- her control themselves.
        { priority = "high", act = "attack", item = "weapon_iron_longbow",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
