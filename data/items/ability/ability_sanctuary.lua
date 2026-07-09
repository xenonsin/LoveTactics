-- Sanctuary: the priest consecrates an area, leaving a Sanctuary hazard on every tile in the blast
-- (data/hazards/hazard_heal.lua). Allies standing on hallowed ground gain Regeneration, mending
-- health each turn; the hazard carries the caster's side, so enemies who wander in gain nothing. A
-- ground-target area cast (target = "tile", allowOccupied) flagged `support` so its footprint
-- previews green like a heal rather than red like an attack.
return {
    name = "Sanctuary",
    description = "Consecrate an area, granting Regeneration to allies who stand within.",
    sprite = "assets/items/ability_sanctuary.png",
    type = "ability",
    tags = { "holy", "restorative" },
    activeAbility = {
        name = "Sanctuary",
        target = "tile",
        allowOccupied = true,
        support = true, -- friendly area cast: preview green
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" }, -- 3x3 consecrated ground
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_heal")
            end
        end,
    },
}
