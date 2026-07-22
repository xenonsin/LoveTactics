-- Acedia's serjeant, and the wall in front of her. Where the ordinary Forsworn Knight punishes the
-- huddle her oath forces (data/characters/character_forsworn_knight.lua), the captain holds the
-- huddle SHUT: the Oathkeeper's Defend brace covers every adjacent ally, so a line of them is a door.
--
-- The bitter joke is that this is the Bastion's own rank-4 doctrine, executed properly, by deserters.
-- They are better at holding a line than anyone the player can buy it from -- which is the argument
-- the whole line has been making, standing on the board in armor.
return {
    name = "Forsworn Captain",
    sprite = "assets/chars/forsworn_captain.png",
    class = "knight",
    stats = {
        health = 98, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 17, magicDamage = 0,
        defense = 20, magicDefense = 10,
        movement = 2,
        speed = 2,
    },
    startingItems = {
        "weapon_iron_mace", "armor_oathkeeper_shield", false,
        false,              false,                     false,
        false,              false,                     false,
    },
    defaultAction = "weapon_iron_mace",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling,
    -- ahead of the posture's ordinary "hit whatever is in reach".
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
