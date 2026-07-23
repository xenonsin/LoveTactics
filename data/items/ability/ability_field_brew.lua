-- Field Brew: the alchemist half of the Herbalist (hunter x alchemist). The Crucible distils in a vat;
-- the Herbalist brews from what the field already grows -- so this lays a 3x3 of Renewal ground
-- (data/hazards/hazard_renewal.lua -- allies standing on it recover), essence pressed straight out of
-- the ground into restorative footing. Where the Wildcraft Poultice mends one body, this makes a patch
-- of the world mend anyone who stands on it: the field, brewed.
return {
    name = "Field Brew",
    description = "Brews a 3x3 of restorative ground from the field: allies standing on it recover.",
    flavor = "No vial, no vat. Just the right leaves, crushed into the dirt where they were already growing.",
    sprite = "assets/items/ability_field_brew.png",
    type = "ability",
    tags = { "restorative" },
    class = "alchemist",
    discipline = "herbalist", -- hunter x alchemist; the Field-brewing mechanic's first stock
    price = 280,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        support = true,
        range = 3,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_renewal", { amount = 6 + fx.level, duration = 12 + fx.level })
            end
        end,
    },
}
