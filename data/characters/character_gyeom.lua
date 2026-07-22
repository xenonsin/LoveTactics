-- Gyeom, the mage companion (humility), and the answer to Pride at the head of the Arcanum's line
-- (docs/story.md, "The Arcanum"). A woman, a gender-neutral name, the virtue buried and not stamped:
-- Gyeom is the Korean 謙 -- humility, the I Ching's hexagram of Modesty, the only one whose every line is
-- auspicious -- the way Saber's name is patience and Kaya's is enough (character_saber.lua,
-- character_kaya.lua). The direct model is Frieren's Fern: no prodigy, just the one who trained every day.
--
-- THE ANSWER TO THE GENERAL SHE FACES, but not her kin. Sublimitas (character_general_pride.lua) is a
-- human who pacted with the Demon Lord for perfect comprehension -- one glance at a working and she owns
-- it -- and is certain she has the measure of every mage she can see. Gyeom is the mage she cannot
-- measure. She showed no gift; she did her best, again and again, and grew formidable, and she still holds
-- she has more to learn. Pride "answers every spell with your own"; humility "meets a spell with a
-- better-practised self, not a bigger one." Same axis, opposite verbs; she is the answer the general refused.
-- She turns on the Arcanum not by resisting a corruption but as a WITNESS who would not call the human
-- cost acceptable just because it was useful (docs/story.md, "The Arcanum").
--
-- HER KIT IS PRACTICE MADE MECHANICAL, and she reads WEAK on purpose -- low displayed magic, a plain wand
-- and a single bolt around the build-around: the Ledger in the center
-- (data/items/utility/utility_ledger.lua), which banks a little strength from every action she takes
-- (data/traits/trait_ledger_diligence.lua) and, once she has done her best four times over, RELEASES what
-- she kept hidden in one heavy strike. She peaks late; a long fight is study, not downtime.
--
-- The other half of her rule -- she cannot be answered -- needs no second hook and rides on that same
-- concealment: Pride answers only what is SHOWN (data/traits/trait_perfect_recall.lua), and a spell
-- answered off her suppressed value is answered off nothing. You can glance a spell; you cannot glance the
-- hours she never put on display. It lives on the Ledger's trait and not here because a blueprint's own
-- `traits` field is never collected -- only an item's is (models/trait.lua).
--
-- `boss = true` gives the recruit fight its integrity: the crown-backed Arcanum brands its own radical and
-- hires you to bring her in (data/quests/arcanum_the_radical.lua); best her and she is yours
-- (Player.recruit), exactly as the Cathedral keeps Amana and the Colosseum keeps Saber. It goes inert the
-- moment she is an ally, when only the Ledger's concealment still stands.
return {
    name = "Gyeom",
    sprite = "assets/chars/gyeom.png",
    portrait = "assets/portraits/gyeom.png", -- large VN portrait for conversations (falls back if missing)
    class = "mage",
    boss = true,
    stats = {
        health = 56, mana = 46, stamina = 10,
        staminaRegen = 2,
        damage = 4, magicDamage = 6,    -- suppressed on purpose: she does not fight to be seen
        defense = 7, magicDefense = 11, -- warded against the magic her line traffics in
        movement = 3,
        speed = 3,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Ledger is the build-around in the
    -- center; a plain wand and a single bolt are all she shows, and the mana potion is what keeps the
    -- practice going long enough to Release.
    startingItems = {
        "weapon_wand",  "ability_fire_bolt", "consumable_mana_potion",
        false,          "utility_ledger",    false,
        false,          false,               false,
    },
    defaultAction = "weapon_wand",
}
