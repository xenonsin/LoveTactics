-- Smoke: the way out of a fight that is going wrong. Thrown, it ENDS the fight and slips the company
-- back onto the map where it stood. Nobody is beaten and nothing is cleared: the fight's place stays
-- armed, so walking back onto it starts the same fight again.
--
-- IT LEAVES BY THE ROUT, not by a door of its own. Combat marks the throw (`slipAway` ->
-- combat.slippedAway, live path only), states/battle.lua's smokeOut hands the fight straight to the
-- launcher's onLoss with `routed` set, and states/game.lua's rout branch does what it does for any
-- company still on its feet: back onto the tile it came from, the same health it walked off with, an
-- injury on whoever is down. A third exit would be a third place for that bookkeeping to go missing.
--
-- NEVER ON A STAIR. The guardian, her ward and the Crown are the work a floor is walked for, and they
-- are won by killing (the author's rule). Nor outside the rift: a scripted fight has no map to slip back
-- onto. The launcher says which (states/game.lua's `smoke` opt, true or a reason), and the gate below
-- reads it off the board through `unit.combat`, so the greyed slot, the refused press and the tooltip
-- all say the same thing.
--
-- Rung 0 and pinned there (Grade.SLOT_PINS): a way out is standing supply, like the draughts. Not the
-- Smoke Bomb (consumable_smoke_bomb), which is a reflex for one body; this ends the fight for everyone.
return {
    name = "Smoke",
    description = "Ends the fight and slips the company back onto the map. Anyone down stays injured. Not on a stair.",
    flavor = "The Undercroft sells it by the pinch. Nobody asks what you needed it for.",
    sprite = "assets/items/consumable_smoke.png",
    type = "consumable",
    tags = { "smoke" },
    class = "rogue",
    price = 25,
    unlockLevel = 0,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        consumesItem = true,
        slipAway = true, -- read by Combat's live cast path, which ends the fight (see the header)
        usable = function(unit)
            local combat = unit and unit.combat
            local ok = combat and combat.smoke
            if ok == true and unit.side == (combat.playerSide or "party") then return true end
            return false, type(ok) == "string" and ok or "Not in this fight."
        end,
        effect = function() end, -- the fight ends on the live path, never in a forecast
    },
}
