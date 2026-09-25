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
--
-- AND IT BRINGS A FLIER DOWN (2026-09-25, on Keno's call). A body On the Wing that the hook catches is
-- stripped of its stacks and Grounded -- the griffin's own fall (trait_on_the_wing), minus the Stun,
-- which stays the prize for beating it out of the air. It takes wing again when Grounded runs out, so a
-- pull buys the window rather than ending the flight. A caught body is one Combat.pull did not refuse:
-- a rooted flier still comes down, because the hook landed even though the body did not travel.
-- Aloft is untouched -- it is untargetable, so the aim never reaches it.
return {
    name = "Pull",
    description = "Hauls a body, barrel or trap in sight to an adjacent tile; a body triggers all it crosses, and a flier is Grounded.",
    flavor = "Pulls an archer out of its dead zone, or a healer out of the back line and into the noise.",
    sprite = "assets/items/ability_pull.png",
    type = "ability",
    class = "bulwark",
    price = 255,
    unlockLevel = 4,
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
                if fx.pull(body) and body.alive and fx.hasStatus(body, "status_on_the_wing") then
                    fx.clearStatus(body, "status_on_the_wing")
                    fx.applyStatus(body, "status_grounded")
                end
                return
            end
            local obj, kind = fx.objectAt(fx.tx, fx.ty)
            if obj then fx.pullObject(obj, kind) end
        end,
    },
}
