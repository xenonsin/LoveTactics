-- The item equivalent of the Melee Counter reflex: a duelist's blade that strikes back on its own.
-- `traits` on an item reach whoever carries it (models/trait.lua), so any character -- not just a
-- born counter-fighter -- can build a retaliation loadout around it. A fighter-class weapon, sold at
-- the Colosseum. The strike it answers with is the wielder's DEFAULT weapon, so pairing it with a
-- heavier blade sharpens the counter.
return {
    name = "Riposte Blade",
    description = "A duelist's sword. When struck in melee, it answers on its own.",
    sprite = "assets/items/riposte_blade.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    class = "fighter",
    price = 220,
    repRank = 2,
    traits = { "melee_counter" },
    activeAbility = {
        name = "Riposte",
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
