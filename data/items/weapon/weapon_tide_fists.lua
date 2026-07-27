-- A water elemental's natural weapon (the aquatic counterpart to the Fire Elemental's Flame Fists).
-- A crashing blow of water that leaves the struck foe Wet -- vulnerable to lightning -- so a water
-- elemental sets up its own follow-up, or a mage's Jolt. `noSteal`: you cannot pocket the sea.
return {
    name = "Tide Fists",
    description = "Batters an adjacent foe and inflicts Wet.",
    flavor = "You cannot pocket the sea. It sets up its own next blow, and never hurries.",
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
            -- Wet rides the blow: it lands on whoever the strike hits, and only a connecting hit --
            -- the > 0 guard the carried path enforces for free.
            fx.damage(fx.target, { inflicts = "status_wet" })
        end,
    },
}
