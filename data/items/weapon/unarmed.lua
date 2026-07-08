-- The default unarmed weapon: a bare-handed strike every unit falls back to when it carries
-- no crafted weapon. Unlike a normal item it is NEVER placed in a character's inventory (it
-- would consume one of the nine slots and show in the item grid); instead models/character.lua
-- attaches an instance to `char.unarmed`, and combat treats it as the fallback attack + the
-- range source for the default-attack (threat) highlight. A character blueprint can name its
-- own unarmed weapon via an `unarmed = "<item id>"` field (e.g. a beast's bite); this file is
-- just the generic fallback.
--
-- `speed` is deliberately Combat.DEFAULT_SPEED (5): a unit with no ability items already used
-- that constant for its starting initiative, so routing the fallback through this weapon keeps
-- the timeline unchanged. The strike is free (no cost) so a basic attack is always available,
-- and weak (a low Power) so it never rivals a real weapon.
return {
    name = "Unarmed",
    description = "A bare-handed strike at an adjacent foe.",
    sprite = "assets/items/unarmed.png", -- never rendered (hidden from the grid); ok if missing
    type = "weapon",
    tags = { "unarmed", "physical" },
    activeAbility = {
        name = "Strike",
        target = "enemy",
        range = 1,
        speed = 5, -- == Combat.DEFAULT_SPEED; keeps the no-ability-items initiative unchanged
        power = 2, -- weak: a low Power so a bare fist never rivals a real weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
