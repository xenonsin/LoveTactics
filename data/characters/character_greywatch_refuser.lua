-- One of the nineteen. When Acedia opened Greywatch's gate and put the terms to her garrison,
-- forty-one took them (data/items/utility/utility_greywatch_muster_roll.lua). These men did not.
--
-- They are the ANTI-FORSWORN, and the pairing is the line's whole thesis in two blueprints: the
-- forsworn kept the Bastion's forms and sold the thing underneath them; these kept the thing and
-- lost the forms. Same gate, same night, opposite answer. The player meets the ones who said no
-- three quests before meeting any of the ones who said yes.
--
-- What happened next is the Bastion's doing, not Acedia's. Nineteen knights returning with that
-- story ends the martyr, and the martyr is the only thing keeping the line manned -- so the order
-- turned them away at the door and struck them off the rolls. Fifteen years later they are eating off
-- a road they used to guard.
--
-- Still in the forms: `bastion_sworn` sprite, sword and shield, the brace the order teaches. They
-- never stopped being knights; they just stopped being allowed to be. Aggression is the DEFAULT
-- posture (no `archetype`) and that is deliberate -- these are not the compliant old men of the
-- premise this quest used to have. They are armed, they are desperate, and they will not be taken.
return {
    name = "Road-Knight",
    sprite = "assets/chars/bastion_sworn.png",
    class = "knight",
    stats = {
        health = 74, mana = 0, stamina = 42,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 11, magicDefense = 5,
        movement = 3,
        speed = 2,
    },
    startingItems = {
        "weapon_iron_sword", "armor_leather_armor", false,
        false,               false,                 false,
        false,               false,                 false,
    },
    defaultAction = "weapon_iron_sword",
}
