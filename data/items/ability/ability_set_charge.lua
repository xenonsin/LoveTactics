-- Set Charge: the alchemist half of the Saboteur (rogue x alchemist). Plants a blast charge on a tile
-- (data/traps/blast_charge.lua) -- a delayed bomb that goes off when a foe crosses it. Greed's guile
-- meets envy's chemistry: the Saboteur does not fight the line, it decides where the floor stops being
-- safe. Paired with the Ghost Kit, which sets them off on command.
return {
    name = "Set Charge",
    description = "Plants a blast charge on a tile: it detonates on the foe that crosses it.",
    flavor = "She never wins the room. She only ever decides which parts of it you may stand in.",
    sprite = "assets/items/ability_set_charge.png",
    type = "ability",
    tags = { "utility" },
    class = "alchemist",
    discipline = "saboteur", -- rogue x alchemist; the Planted-charges mechanic's first stock
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            fx.placeTrap(fx.tx, fx.ty, "blast_charge", { amount = 9 + fx.level })
        end,
    },
}
