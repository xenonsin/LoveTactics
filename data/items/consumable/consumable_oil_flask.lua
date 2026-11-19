-- Oil Flask: the alchemist's Reactions setup for fire (docs/engines.md). Thrown, it slicks everyone in
-- a small burst with Oiled (status_oiled), which does nothing on its own. The next fire that touches an
-- oiled body sets it off: two tiles of fire and burning ground, and any other oiled body in the blast
-- goes up with it (Engine.ignite). Anybody on the line can bring the fire.
--
-- Reworked 2026-11-18 from a flask that laid Vulnerable: Fire, a bigger number on the next fire hit. The
-- reaction is the same promise made into an event the board can see.
return {
    name = "Oil Flask",
    description = "Inflicts Oiled in area. Fire on an Oiled body explodes within 2 tiles.",
    flavor = "The Crucible does not sell you the fire. It sells you the reason the fire works.",
    sprite = "assets/items/oil_flask.png",
    type = "consumable",
    tags = { "oil" },
    class = "alchemist",
    price = 85,
    unlockLevel = 3,
    activeAbility = {
        target = "tile", -- thrown and bursts around the point, like the Acid Bomb
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.alive then fx.applyStatus(u, "status_oiled") end
            end
        end,
    },
}
