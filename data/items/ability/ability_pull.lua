-- The inverse of Push: drag a distant thing up against you. It needs a clear line (`requiresSight`,
-- and Combat.pull / Combat.pullObject check again) -- you cannot hook what you cannot see -- and the
-- target is walked toward you one tile at a time until it stands adjacent. A unit in the way stops it
-- short.
--
-- It aims a TILE, so the same grip reaches a body OR the furniture on it: haul an archer out of its
-- dead zone or a healer out of the back line and into the melee; drag a barrel across the board to your
-- feet without setting it off (a pull hurts nothing -- unlike Heave, it does not burst what it moves);
-- or pluck a trap you have found off the lane it was guarding. A dragged BODY sets off every trap and
-- hazard it is pulled across (Combat.pull walks it through enterTile); a dragged OBJECT does not, the
-- same way a thrown one doesn't.
return {
    name = "Pull",
    description = "Hauls a body, barrel or trap you can see to an adjacent tile; a dragged body triggers all it crosses.",
    flavor = "Pulls an archer out of its dead zone, or a healer out of the back line and into the noise.",
    sprite = "assets/items/ability_pull.png",
    type = "ability",
    tags = { "impact", "physical" },
    activeAbility = {
        target = "tile",       -- a tile in reach, so what is hauled in may be a body or furniture
        allowOccupied = true,
        range = 4,
        minRange = 2, -- pointless on something already beside you
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            -- A body first (a unit and an object never share a tile), otherwise the furniture on the
            -- tile -- a prop, or a trap this side has detected. Bodies route through Combat.pull,
            -- furniture through Combat.pullObject; both re-check the line of sight the aim already asked.
            local body = fx.unitAt(fx.tx, fx.ty)
            if body then
                fx.pull(body)
                return
            end
            local obj, kind = fx.objectAt(fx.tx, fx.ty)
            if obj then fx.pullObject(obj, kind) end
        end,
    },
}
