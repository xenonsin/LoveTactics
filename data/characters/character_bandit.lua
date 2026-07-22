-- Enemy character blueprint. Reuses the party-character schema (models/character.lua):
-- flat base stats, resource stats split into { max, current } on instantiate. Enemies
-- live alongside party members and are placed on the far side of a battle arena.
return {
    name = "Bandit",
    sprite = "assets/chars/bandit.png",
    stats = {
        health = 42, mana = 0, stamina = 13, -- resource stats
        damage = 12, magicDamage = 0,         -- flat stats
        defense = 6, magicDefense = 3,
        movement = 3, -- number of spaces this character can move
        speed = 4,
    },
    startingItems = { "weapon_iron_sword" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
