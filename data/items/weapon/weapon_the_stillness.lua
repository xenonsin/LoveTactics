-- A greatsword, so it winds up (docs/weapons.md). Its extra is the ground it leaves: the tile the blade
-- falls on becomes Stillness (data/hazards/hazard_stillness.lua) -- nothing standing there may take an
-- action at all.
--
-- Quest-only: `class` with no `price`.
--
-- What it buys is a hole in the enemy turn order that you can point at on the board. Every other way this
-- game stops a body from acting is a status applied to a UNIT -- a stun, a Halt, a freeze -- and all of
-- them travel with the victim and can be cleansed off it. This one is a fact about a SQUARE. It cannot be
-- cured, it does not care who is standing in it, and it is still there next turn for whoever walks in
-- next. A greatsword that closes a doorway.
--
-- The cost is that it is unsided, as ground in this game generally is: your own line is stilled by it
-- exactly as happily, and the tile it lands on is by definition the tile directly in front of the
-- greatswordsman -- which is where the rest of the party was probably heading. Swing it at a corridor,
-- not into a melee your friends are already in.
return {
    name = "The Stillness",
    description = "Winds up, then falls on one tile and stills the ground: nothing standing there may act.",
    flavor = "The blow is not what stops them. The blow is only what makes the place where stopping happens.",
    sprite = "assets/items/the_stillness.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        channel = 2,
        cost = { stat = "stamina", amount = 16 },
        -- Under the iron greatsword's: the ground is the rest of the price, and it is worth a lot.
        damage = { 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38 },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
            -- Laid on the aimed CELL rather than on whoever was standing in it, which is the whole
            -- distinction being drawn above -- a body that dies to the blow leaves the stilled ground
            -- behind for the next one. Scales its life off the forge, as every hazard-laying cast does.
            fx.placeHazard(fx.tx, fx.ty, "hazard_stillness", { duration = 10 + fx.level })
        end,
    },
}
