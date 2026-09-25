-- THE COURT: Luxuria's rule, and the whole of it is her army (models/court.lua holds the mechanics;
-- data/characters/character_general_lust.lua is the fight).
--
-- AT THE BELL she takes every humanoid standing on her side -- bound, not taken: they walked on hers and
-- have no side of their own to go back to, so when she falls they come back to themselves and walk out
-- (status_charm's onExpire). Each is sworn to her, and one standing beside her takes the first blow each
-- turn meant for her. She also puts on her rule status (status_the_court), which is what does her
-- turn-start work: taking the newcomers the Procession walks in, quickening it once she is below half,
-- and changing partners when a foe reaches her.
--
-- WHEN HER CHARM LANDS ON THE COMPANY this hook is the ceiling. She may hold one of them while she stands
-- above half her health and two below it; a charm past the cap is shaken off on the spot (removed, so
-- the side-flip reverts through the ordinary path). The planner already refuses to take a side's last
-- free body (AI.lastFreeBody); this is the tighter promise under it -- "easily, but not unfairly".
--
-- ...AND THE FIRST ONE SHE HOLDS EACH FIGHT IS HER CONSORT (status_consort): half again the damage, and
-- sworn to her like the rest of her court. The badge is a rider on the charm and leaves with it.
return {
    name = "The Court",
    description = "Holds every allied humanoid; holds one foe at a time, two below half health, the first as Consort.",
    onCombatStart = function(ctx)
        local Court = require("models.court")
        local me = ctx.unit
        local took = Court.bind(ctx.combat, me)
        ctx.applyStatus(me, "status_the_court", { applier = me })
        if took > 0 then
            ctx.log("status", string.format("%s's court kneels: %d of them.",
                (me.char and me.char.name) or "She", took), me)
        end
    end,
    onStatusApplied = function(ctx)
        local st = ctx.status
        if ctx.role ~= "applier" or not st or st.id ~= "status_charm" or st.bound then return end
        local Court = require("models.court")
        local Status = require("models.status")
        local me, victim = ctx.unit, ctx.recipient
        if not (victim and victim.alive) or st.charmer ~= me then return end
        local held = Court.held(ctx.combat, me)
        if #held > Court.cap(me) then
            Status.remove(ctx.combat, victim, "status_charm")
            ctx.log("status", string.format("%s is holding all she can; %s comes back to itself.",
                (me.char and me.char.name) or "She", (victim.char and victim.char.name) or "the body"),
                { me, victim })
            return
        end
        -- The first of the company she holds this fight becomes her Consort.
        ctx.combat._courtConsort = ctx.combat._courtConsort or {}
        if ctx.combat._courtConsort[me] then return end
        ctx.combat._courtConsort[me] = true
        local dmg = victim.char and victim.char.stats and victim.char.stats.damage
        if type(dmg) == "table" then dmg = dmg.current end
        local bonus = math.max(1, math.ceil((dmg or 0) * 0.5))
        if ctx.applyStatus(victim, "status_consort",
                { applier = me, duration = math.huge, statBonus = { damage = bonus } }) then
            ctx.log("status", string.format("%s takes %s as her Consort.",
                (me.char and me.char.name) or "She", (victim.char and victim.char.name) or "the body"),
                { me, victim })
        end
    end,
}
