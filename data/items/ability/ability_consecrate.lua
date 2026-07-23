-- Consecrate: the priest half of the Paladin (knight x priest). Raises hallowed ground that shields
-- (data/hazards/hazard_shared_bulwark.lua -- every ally standing in it carries a physical barrier that
-- swallows a blow whole). The knight's wall said in the priest's voice: not a body between the enemy
-- and the line, but a patch of ground that guards everyone who holds it.
return {
    name = "Consecrate",
    description = "Consecrates an area: allies who stand within carry a barrier that swallows a blow.",
    flavor = "The wall need not be a person. Sometimes it is only where you choose to stand.",
    sprite = "assets/items/ability_consecrate.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "paladin", -- knight x priest; the Ward-aura mechanic's first stock
    price = 320,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        support = true,
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_shared_bulwark", { duration = 10 + fx.level })
            end
        end,
    },
}
