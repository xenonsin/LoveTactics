-- Smite: the priest half of the Crusader (fighter x priest). A holy blow that leaves the ground it lands
-- on consecrated (data/hazards/hazard_heal.lua) -- allies who hold the tile mend, and the hazard knows
-- whose side it is on. Keeps the name the shelf always wanted; the priest's answer is a ZONE, not a
-- heal-on-kill. Carries `holy`, so demonic flesh takes far more (utility_demonic_essence.lua).
return {
    name = "Smite",
    description = "A holy strike that leaves consecrated ground: allies who stand on it regenerate.",
    flavor = "The blow is for them. The ground it blesses is for you.",
    sprite = "assets/items/ability_smite.png",
    type = "ability",
    tags = { "holy", "impact" },
    class = "priest",
    discipline = "crusader", -- fighter x priest; the Smite mechanic's first stock
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }, -- carries `holy` via the item tags
        effect = function(fx)
            fx.damage(fx.target)
            fx.placeHazard(fx.target.x, fx.target.y, "hazard_heal", { amount = 6 + fx.level, duration = 12 + fx.level })
        end,
    },
}
