-- A greatsword, so it winds up (docs/weapons.md) -- and it is the only one whose wind-up the player
-- chooses the LENGTH of. `windup = { min, max }` (the chargeable wind-up Saber's signature introduced,
-- data/items/weapon/weapon_first_motion.lua) lets the bearer hold the raise for two ticks or four,
-- and what those extra ticks buy is not damage but FOOTPRINT: the blow lands as a 3-wide arc instead
-- of a single tile.
--
-- The family shelf's capstone, and the one weapon that lets a greatsword answer a crowd. Every other
-- greatsword pours everything into one cell -- that is what separates the family from the axe -- and this
-- one can decide, at cast time and with the board in front of it, to be an axe instead. It is deliberately
-- the CHOICE that is rare rather than the arc: an axe cleaves three tiles every swing for far less, and
-- what this buys is three tiles at a greatsword's Power on the one turn it matters.
--
-- The cost is honest and steep: two extra ticks of telegraph against an enemy line that can read the
-- turn order as well as you can. Held at full depth this is the longest commitment in the game.
local Curve = require("models.curve")

return {
    name = "Avalanche",
    description = "Channeled: hold longer to widen the arc.",
    flavor = "Snow does not decide to come down. It only decides how much of the mountain is coming with it.",
    sprite = "assets/items/avalanche.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    price = 740,
    unlockQuests = 8,
    activeAbility = {
        description = "Holding the wind-up longer widens the blow: two extra ticks turn one tile into a three-tile arc.",
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        -- The raise, in TOTAL ticks: two is the greatsword family's base and where this looses if the
        -- bearer commits to nothing, up to four for the full arc below. (It read `channel = 2` plus
        -- `windup = { min = 0, max = 2 }` before the two fields folded into one -- same tell, said once.)
        windup = { min = 2, max = 4 },
        cost = { stat = "stamina", amount = 17 },
        -- A shade under the iron greatsword's: what the extra ticks buy is width, and it must not also
        -- quietly buy weight, or holding would never be wrong.
        damage = Curve.ramp(50, 76),
        -- The declared footprint is the WIDE one, so the aim preview and fx.aoeUnits agree on the shape
        -- the swing can reach. The effect below narrows it back to the single aimed body when the bearer
        -- chose not to hold -- narrowing in the effect is safe (the preview over-promises reach, never
        -- damage), where widening in the effect would not be.
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            -- Fewer than two ticks poured in ON TOP of the base raise (fx.held, not the total tell in
            -- fx.windup) and it is an ordinary greatsword: one tile, one body.
            if (fx.held or 0) < 2 then
                if fx.target then fx.damage(fx.target) end
                return
            end
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
