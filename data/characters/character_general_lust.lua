-- The general of Lust, and the end of the Cathedral's line (docs/story.md). Enemy blueprint; the
-- objective of data/quests/general_lust.lua. The finale (data/quests/the_gate_below.lua) already reserves
-- a slot for her -- "general_lust" sits in its requiredQuests.
--
-- Her whole fight is one rule, and it rides on the reliquary in her grid (a blueprint's own `traits`
-- field is never collected; only an item's is -- models/trait.lua): she takes what you hold back
-- (data/traits/trait_rapture.lua). Every blow she lands draws off the stamina and mana the target was hoarding and
-- takes it into herself as health -- so a party that fights her the ordinary way, husbanding resources for
-- the big turn, feeds her the whole time. The counterplay is the sin read as tactics: SPEND, let nothing
-- sit unspent near her. And the one unit she can never draw from is Amana (character_amana.lua), who held
-- nothing back to begin with -- the companion answering this general.
--
-- SAME WOUND AS AMANA, two answers (see her file). At the finale Luxuria offers the one thing that could
-- break her foil -- Amana's birth-name, the self the Cathedral took -- because taking Amana's allegiance
-- is beyond even her: a will already given away cannot be seized. Statted as a hungry duelist rather than
-- a wall: middling everything, kept alive by what she drinks off you. `assassinate` is the honest
-- objective -- her guard is a wall to pass, and every turn spent grinding it is a turn she feeds on.
--
-- Her reliquary carries her rule for whoever lifts it (data/items/utility/utility_reliquary_unbidden.lua).
return {
    name = "Luxuria, the Unbidden",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_lust.png",
    portrait = "assets/portraits/general_lust.png", -- large VN portrait for conversations (falls back if missing)
    stats = {
        health = 200, mana = 60, stamina = 100,
        staminaRegen = 2,
        damage = 14, magicDamage = 10, -- middling; the drink is what keeps her standing
        defense = 14, magicDefense = 14,
        movement = 3,
        speed = 4,
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Her rule rides on the Reliquary of
    -- the Unbidden in the center (bound, unstealable), the censer of ashes -- the lust family read from the
    -- taking side (data/items/weapon/weapon_censer_of_ashes.lua) -- beside it.
    startingItems = {
        false, false,                        false,
        false, "utility_reliquary_unbidden", "weapon_censer_of_ashes",
        false, false,                        false,
    },
}
