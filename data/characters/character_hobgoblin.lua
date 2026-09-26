-- THE HOBGOBLIN: the goblins' alpha, and the one goblin that is not angry (approved as pitched, 2026-09-26, "The
-- Goblins of Wrath").
--
-- IT ESCALATES IN KIND, NOT IN SIZE. The warband's Feud goes to whoever hits them; the Hobgoblin PICKS it -- Name
-- the Enemy marks any foe within 5 -- and while it stands the company loses the Feud lever. The Lash whips a goblin
-- within 2 into acting again at once, for a tenth of its health. Kill it and the warband goes back to chasing
-- whoever hurts it, which the company controls again.
--
-- It drops the Lash, which does both halves in a player's hand. A warlord on the fighter table; the alpha never
-- cowers alone.
return {
    name = "Hobgoblin",
    race = "goblin",
    tier = 3,
    class = "fighter",
    discipline = "warlord",
    sprite = "assets/chars/hobgoblin.png",
    archetype = "aggressive",
    stats = {
        health = 104, mana = 0, stamina = 28,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 7, luck = 5,
    },
    startingItems = {
        "weapon_hobgoblins_lash", "ability_name_the_enemy", "ability_the_lash",
        false,                    false,                    false,
        false,                    false,                    false,
    },
    drops = { "weapon_hobgoblins_lash" },
    defaultAction = "weapon_hobgoblins_lash",
    signatureWeapon = "weapon_hobgoblins_lash",
}
