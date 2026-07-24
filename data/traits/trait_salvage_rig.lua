-- Salvage Rig: the standing rule of the Artificer's charm. A construct of the bearer's that is destroyed
-- bursts, and the wreck is refunded as mana.
--
-- The third thing wrong with turrets: they die for nothing. An emplacement that has been cut down has
-- cost the artificer a cast, a reservation and a turn, and paid out only the damage it managed before it
-- fell. This makes losing one a plan -- an artificer can emplace a sentry INTO a line knowing the answer
-- to it is an explosion.
--
-- Hangs on onSummonLost, which had to be added for it -- and the reason is worth reading, because it is
-- the whole shape of the problem. The general death broadcast (Trait.onAnyDeath) deliberately EXCLUDES
-- summons: a conjuration winking out is not a body hitting the ground, and a summoner farming its own
-- wolves must not feed every death-reflex on the field. But the construct itself carries no grid for a
-- rule to hang from, so a wreck has nowhere to speak from either. onSummonLost is the narrow answer --
-- one hook, delivered to the summoner alone, fired only for a real conjuration.
--
-- The burst is dealt through the model rather than an ability, so it has no caster to counter and
-- provokes nothing. A wreck is not a swing.
return {
    name = "Salvage Rig",
    magnitude = 12, -- damage to everything adjacent to the wreck, and mana handed back
    onSummonLost = function(ctx)
        local fallen = ctx.lost
        if not (fallen and ctx.unit.alive) then return end
        local Combat = require("models.combat")
        local blast = ctx.def.magnitude or 12
        for _, u in ipairs(Combat.unitsNear(ctx.combat, fallen.x, fallen.y, 1)) do
            if u.alive and u.side ~= ctx.unit.side then
                Combat.dealFlatDamage(ctx.combat, u, blast, { "physical", "impact" }, "the wreck")
            end
        end
        Combat.restoreResource(ctx.unit.char, "mana", blast)
        ctx.log("action", string.format("%s's construct comes apart usefully.",
            (ctx.unit.char and ctx.unit.char.name) or "The artificer"), ctx.unit)
    end,
}
