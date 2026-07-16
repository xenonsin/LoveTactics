-- A water elemental's natural weapon (the aquatic counterpart to the Fire Elemental's Flame Fists).
-- A crashing blow of water that leaves the struck foe Wet -- vulnerable to lightning -- so a water
-- elemental sets up its own follow-up, or a mage's Jolt. `noSteal`: you cannot pocket the sea.
return {
    name = "Tide Fists",
    description = "Batter an adjacent foe with water, leaving them Wet.",
    sprite = "assets/items/tide_fists.png",
    type = "weapon",
    tags = { "natural", "water", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 },
        effect = function(fx)
            if fx.damage(fx.target) > 0 then
                fx.applyStatus(fx.target, "wet")
            end
        end,
    },
}
