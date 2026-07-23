-- A hawk's natural weapon: the light end of the beast shelf, softer even than a wolf's Fangs
-- (data/items/weapon/weapon_fangs.lua), because a hawk is a spotter, not a killer -- see
-- data/traits/trait_falconers_hawk.lua. `natural`, `noSteal`, sold by nobody: a creature's body is not
-- loot, and no vendor stocks it (docs/classes.md, "Monk, and why there is no fist weapon").
return {
    name = "Talons",
    description = "A hawk's talons: a quick, shallow rake.",
    flavor = "Enough to draw blood and break a line of sight. Never enough to end anything.",
    sprite = "assets/chars/hawk.png",
    type = "weapon",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a hawk's talons cannot be lifted off it
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3, -- fast, matching a light quick strike
        cost = { stat = "stamina", amount = 4 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- softer than Fangs: the bird is not the threat
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
