-- THE BOX OF GRAVE-EARTH: the Sire's second drop (data/items/utility/utility_box_of_grave_earth.lua). The first
-- time a blow would down its bearer, it turns to mist instead (Trait.trySurvive's `mistsOnLethal`): it drifts
-- back to the tile it opened the fight on, cannot be targeted or hurt there, and re-forms at 30% at the start of
-- its next turn (status_grave_mist). Once a fight.
--
-- BESIDE THE DOWNED SYSTEM, not inside it: it fires where Second Wind does, BEFORE a company body would be
-- incapacitated, so the bearer never goes down at all that once. The next lethal blow downs it as usual.
return {
    name = "Box of Grave-Earth",
    description = "Once a fight, instead of being downed, drift as mist to your starting tile. Re-form there next turn at 30% health.",
    mistsOnLethal = true,
    notAReaction = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if u then u._graveStart = { x = u.x, y = u.y } end
    end,
}
