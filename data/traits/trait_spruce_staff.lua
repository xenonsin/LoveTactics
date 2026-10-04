-- SPRUCE STAFF: the Old Spruce's trophy rule (data/items/weapon/weapon_spruce_staff.lua; "Sloth's Bestiary",
-- 2026-10-04). Each turn the bearer attacks nothing, a root rises on an empty tile beside it (data/walls/roots.lua).
--
-- "ATTACKS NOTHING" is read off the casts the turn made: one aimed at a foe, or one that dealt damage, is an
-- attack. A Focus (the staff's own Wait), a move, a heal or a ward is not -- so the staff's two halves are one
-- habit: stand, breathe, and let the wood come up. The root rises toward the nearest foe (models/sloth_dreamers).
-- A root is a wall to everybody, the bearer's own side included; the company has to walk round it too.
return {
    name = "Spruce Staff",
    description = "Each turn you attack nothing, a root rises on an empty tile beside you. Foes cannot cross Roots.",
    onCast = function(ctx)
        local ab = ctx.ability
        if (ctx.damageDealt or 0) > 0 or (ab and ab.target == "enemy") then ctx.unit._spruceStruck = true end
    end,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        if u._spruceStruck then
            u._spruceStruck = nil
            return
        end
        require("models.sloth_dreamers").growRoot(ctx.combat, u, { { x = u.x, y = u.y } })
    end,
}
