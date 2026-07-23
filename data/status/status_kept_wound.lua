-- Kept Wound: a ward that does not forgive what it swallows -- it KEEPS it, and hands the whole
-- accumulated total to the ground around its bearer when it finally lets go.
--
-- The barrier half is ordinary: `negates = "physical"`, one blow per charge, spent through
-- Status.consumeBarrier like any other. What is not ordinary is `absorbed`, which Combat.dealFlatDamage
-- banks onto the instance at the single place a ward eats a blow -- the PRE-mitigation figure, since the
-- ward stood in front of the armor. This status is the only thing in the game that reads it back.
--
-- WHY IT MATTERS. Shielding an ally has always been a purely defensive turn: you spend an action and
-- the board is exactly as it was, minus one blow. This makes warding an AGGRESSIVE play -- the harder
-- the enemy hits your ward, the worse the answer is, and the answer lands where they are standing,
-- which is next to the person they were hitting. It rewards putting the shield on the unit the enemy
-- most wants dead, rather than on the unit least able to take a hit.
--
-- Both endings are the same ending, which is what Status.remove's contract already guarantees: whether
-- the last charge is spent or the duration simply runs out, onExpire fires and the wound is given back.
-- A ward that was never tested has nothing banked and bursts for nothing -- honest, and worth knowing
-- before you cast it on somebody nobody is aiming at.
return {
    name = "Kept Wound",
    abbr = "Kept",
    description = "Kept: absorbs physical blows, then bursts for everything it swallowed.",
    color = { 0.80, 0.44, 0.52 }, -- badge tint (held blood)
    duration = 15,                -- ~3 turns for the enemy to feed it
    magnitude = 2,                -- blows it swallows; the granting spell raises it per level
    negates = "physical",
    onExpire = function(ctx)
        local kept = ctx.status.absorbed or 0
        if kept < 1 then return end
        -- Everything it ate, thrown at everyone standing beside the bearer -- BOTH sides, on the same
        -- rule every other burst in this game follows: an explosion has never cared whose it was, and a
        -- priest who wards the front-liner in the middle of their own line has made a real decision
        -- rather than a free one. The bearer itself is spared: it is the one who took the hits.
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, 1)) do
            if u ~= ctx.unit and u.alive then
                ctx.damage(u, kept, { "magical", "holy" })
            end
        end
        ctx.log("status", string.format("%s's Kept Wound bursts for %d.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit", kept), ctx.unit)
    end,
}
