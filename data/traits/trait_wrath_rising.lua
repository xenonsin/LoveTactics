-- Ira's rule, and the line's thesis in one hook (docs/story.md, "The Colosseum: wrath, designed").
--
-- She was blind from birth and raised in the Perennial's program to feel nothing -- no fear response,
-- no pain response, no attachment. The first sensation of her life was rage, and it is still the only
-- one that reaches her. So this is NOT anger-scaling. It is the threshold of sensation, and the
-- threshold is nearly death: the closer she is to dying, the more of her comes back.
--
-- She is not most dangerous when she is winning. She is most AWAKE when she is dying, and she goes
-- looking for it.
--
-- WHAT CHANGED, and why. This used to bank a flat bonus per blow survived (`onDamaged` -> +3, over
-- and over), which reads as "hit it and it gets angry" -- a generic berserker. Scaling off MISSING
-- HEALTH says the actual character: the bonus is a function of how close she is to gone, not of how
-- many times you touched her. Hitting her once for forty and forty times for one now differ by
-- exactly what they should differ by.
--
-- MONOTONIC on purpose (`want > have`): healing her does not calm her down. Nothing she has ever felt
-- has gone away, and rage a potion could soothe would be a mood rather than a self.
--
-- The bonus lives in `ctx.addBonus`, which writes the unit's per-battle `bonus` table -- never the
-- shared character instance -- so it does not follow the blueprint into the next battle, nor follow a
-- party member back to the hub who lifted her mail off her body
-- (data/items/armor/armor_mail_of_the_unappeased.lua). `ctx.trait.stacks` holds the bonus applied so
-- far, so each blow adds only the difference rather than re-adding the whole curve.
--
-- The `wrath` status alongside grants NOTHING: it exists so the player can watch the number climb and
-- work out, before it is too late, that a long trade is how she wins. The counterplay is Saber's, and
-- it is the same axis read backwards (data/items/weapon/weapon_first_motion.lua): Ira scales as her
-- own health falls, Saber scales with her target's. Grind Ira down and you are waking her up.
return {
    name = "Rising Wrath",
    description = "The nearer it is to death, the harder it hits.",
    magnitude = 20, -- the damage it is worth at death's door, scaled by how much health is gone
    onDamaged = function(ctx)
        local hp = ctx.unit.char.stats.health
        local max = hp.max or 0
        if max <= 0 then return end

        -- 0 at full health, approaching 1 as she is emptied.
        local gone = 1 - ((hp.current or 0) / max)
        local want = math.floor(ctx.def.magnitude * gone)
        local have = ctx.trait.stacks or 0
        if want <= have then return end

        ctx.addBonus("damage", want - have)
        ctx.trait.stacks = want
        ctx.applyStatus(ctx.unit, "status_wrath", { magnitude = want })
    end,
}
