-- Quest reward, slot 3 of the Bastion's line (data/quests/held_position.lua). What the garrison
-- east of the river drinks on the third night, when the post has nothing behind it and nobody is
-- coming and the watch has to be stood anyway.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth when it is
-- used (docs/classes.md, "class without price").
--
-- The hold made portable. `hold` is the knight's whole thesis as a win type (models/arena.lua), and
-- what it actually costs is stamina and a braced stance in the same instant -- so the flask pays
-- both. Deliberately weaker than a Stamina Potion on the restore alone; you are buying the brace.
return {
    name = "Watchpost Draught",
    description = "Restores stamina to an ally and braces them where they stand.",
    flavor = "Third night on a post with nothing behind it. The watch is stood anyway, so it may as " ..
        "well be stood awake.",
    sprite = "assets/items/watchpost_draught.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "knight",
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        support = true,
        range = 1,
        speed = 2,
        consumesItem = true,
        restore = { 18, 19, 21, 22, 24, 25, 27, 28, 30, 31, 33 }, -- under the Stamina Potion's line
        restoreStat = "stamina",
        effect = function(fx)
            fx.restore(fx.target, "stamina", fx.amount)
            fx.applyStatus(fx.target, "status_defending")
        end,
    },
}
