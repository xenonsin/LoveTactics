-- LURE: it pulls one body out of your line, and the forest is what makes that fatal.
--
-- The Lust circle's control rule. Charm already exists and already does the hard part; what this adds is
-- that the pull happens as the body ACTS, so it is attributable to something you can kill rather than
-- being weather.
--
-- WHY THE FOREST. The `glades` carve is open trails through thick cover (data/biomes/forest.lua), which
-- makes it the game's ambush board -- and a formation broken in cover is a formation fighting alone,
-- one body at a time, against things it cannot see. Every other circle's control costs you a turn; this
-- one costs you the shape of your company.
--
-- On a cooldown rather than every cast, because a Lure that fired constantly would be a lock rather than
-- a decision, and the counterplay (kill the Chorister, or close the gap it opened) needs turns to happen
-- in.
return {
    name = "Lure",
    description = "Charms a foe as the singer's blow lands, then goes on cooldown.",
    cooldown = 14,
    -- THE PLANNER READS THIS, and it is the only way it can. A charm delivered by a weapon shows up in
    -- Combat.previewAbility as a status on the struck body, so AI.plan can see it coming and refuse to
    -- take a side's last free body with it; a charm delivered by a TRAIT hangs off the cast rather than
    -- off the ability, and no preview of the Chorister's touch mentions it. So the bearer declares it
    -- instead, and the planner asks Trait.flag(unit, "charms") -- the same shape `carriesLastElement` is
    -- read in. Without it the one body in the circle whose whole job is taking people would be the one
    -- body exempt from the rule about not taking the last of them.
    charms = true,
    onCast = function(ctx)
        -- Cooldowns are KEYED, so the id is passed on both sides -- an unkeyed call would share a slot
        -- with whatever else the bearer is tracking (see trait_opportunist for the same pair).
        if ctx.onCooldown("trait_lure") then return end
        -- A CALL THAT MISSED IS NOT A CALL. onCast fires on a thrown swing as readily as on a landed
        -- one, so before accuracy this was a rider that could not miss riding a blow that could -- the
        -- Chorister whiffed and took the body anyway. Gated on the cast having drawn blood
        -- (Combat.useItem passes the total along), which is the same promise weapon_petal_touch keeps
        -- by carrying its charm inside the hit. Nothing is spent on a miss: the cooldown below is not
        -- set either, so the singer may try the same body again next turn.
        if (ctx.damageDealt or 0) <= 0 then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        -- Named as the applier so the status turns the body onto THIS singer's side (the flip lives in
        -- data/status/status_charm.lua, and reads ctx.applier).
        ctx.applyStatus(target, "status_charm", { applier = ctx.unit })
        ctx.setCooldown("trait_lure", ctx.def.cooldown or 14)
        ctx.log("action", string.format("%s is called, and goes.",
            (target.char and target.char.name) or "Somebody"))
    end,
}
