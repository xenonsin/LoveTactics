-- A demon imp: the runt of the Demon Lord's horde, and the first thing anyone in this game kills.
-- The village attack fields three of them (states/prologue.lua), and their entire job is to be a
-- lesson rather than a threat -- see data/tutorials/village.lua.
--
-- Every number here is tuned against the avatar's opening kit, and they are tuned TIGHT:
--
--   * health 14 dies to exactly one strike of the starting iron sword (power 6 + Damage 12 - the
--     2 defense below = 16), which is what lets the very first step of the lesson be "swing, and
--     watch it fall" instead of "swing three times".
--   * ...and to exactly one Clear Out (data/items/ability/ability_clear_out.lua), which is the last step:
--     the same 16 to everything standing next to you.
--
-- So a change to the sword, to Clear Out, or to these two lines breaks the prologue's whole shape. The
-- heavier Demon Grunt (data/characters/character_demon_grunt.lua) is what the horde fields once the
-- teaching is over.
return {
    name = "Imp",
    sprite = "assets/chars/demon_imp.png",
    stats = {
        health = 14, mana = 0, stamina = 8,
        staminaRegen = 2,
        damage = 4, magicDamage = 7, -- it spits hellfire; the claws are for show
        defense = 2, magicDefense = 2,
        movement = 4,
        speed = 2, -- slower than the avatar and Rowan both: the party always opens
    },
    -- Its body IS its weapon, and that weapon deliberately keeps its distance (see the file).
    startingItems = { "weapon_cinder_spit" },
    defaultAction = "weapon_cinder_spit",
    -- Basic tactics (models/ai.lua): even the runt spits at the softest thing standing. Press the foe
    -- already closest to falling. (The prologue's scripted opening still drives the tutorial imps; this
    -- is what they do once off the leash.)
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
