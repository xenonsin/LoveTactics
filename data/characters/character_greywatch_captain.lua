-- The man who counted the nineteen and wrote them down (data/items/utility/utility_names_he_kept.lua).
-- Acedia's under-officer at Greywatch, who stood in the gateway on the night of the terms and did
-- not take them.
--
-- `guard` (leash 4): he holds the camp. He has spent fifteen years not chasing anything -- there is
-- nowhere to chase it to. Mechanically it also keeps slot 2 from becoming a rout, since the player is
-- meant to be able to look at this fight for a moment before committing to it.
--
-- Deliberately NOT a forsworn captain (data/characters/character_forsworn_captain.lua), and the
-- silhouettes must not converge: that one is Acedia's, kept the forms, sold the substance. This one
-- is the other answer to the same question. The player should not be able to tell yet that the two
-- were in the same gateway on the same night, and nothing in slot 2 may say so.
return {
    name = "Road-Captain",
    sprite = "assets/chars/bastion_sworn.png",
    class = "knight",
    archetype = "guard",
    stats = {
        health = 68, mana = 0, stamina = 13,
        staminaRegen = 2,
        damage = 14, magicDamage = 0,
        defense = 13, magicDefense = 6,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_sword", "armor_chainmail", false,
        false,               false,             false,
        false,               false,             false,
    },
    defaultAction = "weapon_iron_sword",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    -- His `guard` leash still holds him to the camp; this only decides who he strikes once they come.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
