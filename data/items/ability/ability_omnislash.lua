-- Omnislash: a single-target flurry whose power grows with the arsenal around it. For every WEAPON
-- sitting adjacent to this ability in the 3x3 item grid (diagonals included) its damage multiplier
-- climbs by one -- surround it with blades to make it hit like all of them at once. The
-- `adjacencyScaling` descriptor lets the UI draw connector lines to the weapons feeding it (see
-- Combat.adjacencyLinks) using the same predicate the effect scales off.
return {
    name = "Omnislash",
    description = "A single devastating flurry. Damage multiplies for each adjacent weapon.",
    sprite = "assets/items/ability_omnislash.png",
    type = "ability",
    tags = { "slash", "physical" },
    activeAbility = {
        name = "Omnislash",
        target = "enemy",
        range = 1,
        speed = 6, -- a heavy commitment
        cost = { stat = "stamina", amount = 12 },
        power = 6,
        adjacencyScaling = { type = "weapon" }, -- +1x damage per adjacent weapon (UI + effect)
        effect = function(fx)
            local weapons = fx.adjacentMatching({ type = "weapon" })
            -- Base hit at 1x, +1x per adjacent weapon. opts.power overrides the declared Power.
            fx.damage(fx.target, { power = fx.power * (1 + weapons) })
        end,
    },
}
