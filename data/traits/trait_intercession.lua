-- Intercession: the staff-borne half of the Cathedral's oddest bargain. At the start of battle the
-- bearer NAMES one ally, and from then on every blow its Intercessor's Staff lands on an enemy mends
-- that one body instead of the wielder's (the healing itself is the staff's own effect -- see
-- data/items/weapon/weapon_intercessors_staff.lua). This trait does nothing but choose, and record the
-- choice on the unit as `unit.intercession`.
--
-- WHY IT IS LUST'S. The shelf's line is "holds ground open and closes it to others", and its sin is
-- attention that was never asked for. This is that in a verb: the intercessor picks somebody, without
-- consulting them, and pours everything it does into them for the rest of the fight -- and the one
-- named cannot decline, cannot swap, and gets no say in being the reason a priest keeps swinging. A
-- Crozier asks where to stand so the party benefits (data/items/weapon/weapon_crozier.lua). This asks
-- nothing. It is devotion with a target and no consent, which is the Cathedral entire.
--
-- KNOWN GAP, exactly the one data/traits/trait_oathward_declared.lua carries and for the same reason:
-- the ward should be the PLAYER's pick at combat start, and there is no pre-combat prompt yet (one owes
-- mouse + keyboard + gamepad like everything in ui/). Until there is, this names the ally with the LEAST
-- health, which keeps the mechanic and loses the choice. Wire the prompt and delete the fallback -- and
-- note that when it is wired, this and the declared oathward want the SAME prompt, not two.
return {
    name = "Intercession",
    description = "Names one ally at the start of battle. Your intercessor's staff mends them with every blow it lands.",
    onCombatStart = function(ctx)
        local best, bestHp
        for _, u in ipairs(ctx.combat.units) do
            if u.alive and u.side == ctx.unit.side and u ~= ctx.unit then
                local hp = u.char and u.char.stats and u.char.stats.health
                local left = (hp and hp.current) or math.huge
                if not best or left < bestHp then best, bestHp = u, left end
            end
        end
        -- Alone on the field: there is nobody to pray at, and the staff simply heals nobody. Deliberately
        -- NOT falling back on the wielder -- an intercession with no one on the other end of it is just
        -- lifesteal, and the whole point of the item is that the benefit lands somewhere else.
        if not best then return end

        ctx.unit.intercession = best
        -- The badge is for the player, not the model (see data/status/status_intercession.lua).
        ctx.applyStatus(best, "status_intercession")
        ctx.log("system", string.format("%s names %s, and does not ask.",
            (ctx.unit.char and ctx.unit.char.name) or "The intercessor",
            (best.char and best.char.name) or "an ally"))
    end,
}
