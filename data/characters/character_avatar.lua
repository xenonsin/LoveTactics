-- The player's created avatar -- the survivor of the burning village the whole game is played as.
-- Not one of the seven (see docs/story.md); has no class of its own and grows into whatever the
-- player casts (Growth.NEUTRAL_CLASS is fighter, the class-less fallback). Starts with a sword and
-- the coat off their own back -- the prologue's overworld leg introduces the remaining item types one
-- at a time.
--
-- The leather is there so the armour slot is not empty on the first Loadout screen the player ever
-- opens. It is also the baseline the movement economy is tuned against: base 4, less the coat's one
-- square, is 3 -- the pace every enemy in the prologue moves at, so the opening fights read fairly
-- while the player is still learning that armour costs pace at all (see armor_padded_vest's header).
--
-- THE STAT BLOCK IS SYMMETRIC ACROSS THE TWO SCHOOLS -- damage equals magicDamage, defense equals
-- magicDefense -- and that is the blueprint agreeing with the paragraph above it. This is the one
-- body in data/characters/ that declares no class and grows into whatever the player casts
-- (models/growth.lua blends the level's gains across the ledger). A lopsided 12/4 opening said the
-- opposite: it handed the player a swordsman and then invited them to become a mage from three
-- points behind, so the first Fireball they ever threw was worse than the sword they were told to
-- put down. A blank slate has to be blank on both sides, or the choice it offers is rhetorical.
--
-- The physical half is unchanged from that old block and cannot move: 12 is what makes the starting
-- sword (power 6) fell an imp in exactly one stroke, which is the prologue's opening lesson, and 8
-- defense is what prices the Demon Grunt's claw at the 20 the mana lesson is argued from (see
-- data/characters/character_demon_imp.lua and data/tutorials/village.lua). The magic half came UP to
-- meet it rather than the physical half coming down, for that reason alone.
--
-- The blueprint name is "Stranger": the avatar is nameless until the Colosseum announcer asks, and
-- the typed name is written onto the instance (char.name) then -- see states/prologue.lua and the
-- per-character name override in models/save.lua. Gender (and thus the sprite) is chosen at
-- character creation and set on the instance there (states/character_creation.lua builds it via
-- states/prologue.lua's begin).
return {
    name = "Stranger",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/avatar_1.png", -- default; overridden by the chosen body at creation
    portrait = "assets/portraits/avatar_1.png",
    stats = {
        health = 62, mana = 20, stamina = 15,
        staminaRegen = 2,
        damage = 12, magicDamage = 12,
        defense = 8, magicDefense = 8,
        movement = 4,
        speed = 3,
    },
    startingItems = { "weapon_iron_sword", "armor_leather_armor" },
    defaultAction = "weapon_iron_sword",
    -- Basic tactics (models/ai.lua): the starting instinct under auto-battle -- go finish the foe
    -- already closest to falling before spreading damage around. The player overrides all of this from
    -- the Tactics tab.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
