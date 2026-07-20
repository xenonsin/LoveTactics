-- Ira's rule, and the line's thesis in one hook (docs/story.md, "The Colosseum: wrath, designed").
--
-- She was blind from birth and raised in the Perennial's program to feel nothing -- no fear response,
-- no pain response, no attachment. The first sensation of her life was rage, and it is still the only
-- one that reaches her. So this is NOT anger-scaling. It is the threshold of sensation, and the
-- threshold is nearly death: the closer she is to dying, the more of her comes back.
--
-- She is not most dangerous when she is winning. She is most AWAKE when she is dying, and she goes
-- looking for it -- and short of that, she will take being hit at all.
--
-- WHAT CHANGED, and why. This used to bank a flat bonus per blow survived and nothing else, which
-- reads as a generic berserker: hit it, it gets angry, and forty scratches were worth more than one
-- killing blow. The health term is what makes it HER -- the bonus is mostly a function of how close
-- she is to gone, so a party that opens big and a party that whittles no longer arrive at the same
-- place by the same road.
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
-- TWO SOURCES, and the second one exists to close a hole the first leaves open. Missing health alone
-- means a party that chips her with many small, heavily mitigated blows barely moves the curve while
-- very much fighting her -- her own armour would be quietly protecting the player from her rule. So
-- every blow that lands counts as well, whatever it was worth.
--
-- That is also the truer reading of her. What reaches her is CONTACT. A blow that glances off is
-- still someone touching her, and she was raised in a place where nothing did.
--
--   bonus = floor(magnitude x fraction of health gone)  +  perBlow x blows survived
--
-- Deep hits move the first term, sheer volume moves the second, and neither route lets you fight her
-- for free. `ctx.trait.stacks` counts the blows (its documented purpose as the free accumulator);
-- `ctx.trait.applied` holds the bonus granted so far, so each hit adds only the difference.
return {
    name = "Rising Wrath",
    description = "Sharpens with every blow it takes, and worse the nearer it is to death.",
    magnitude = 20, -- the damage the health curve is worth at death's door
    perBlow = 1,    -- and what mere contact is worth, mitigated to nothing or not
    onDamaged = function(ctx)
        local hp = ctx.unit.char.stats.health
        local max = hp.max or 0
        if max <= 0 then return end

        ctx.trait.stacks = (ctx.trait.stacks or 0) + 1

        -- 0 at full health, approaching 1 as she is emptied.
        local gone = 1 - ((hp.current or 0) / max)
        local want = math.floor(ctx.def.magnitude * gone) + (ctx.def.perBlow * ctx.trait.stacks)
        local have = ctx.trait.applied or 0
        if want <= have then return end

        ctx.addBonus("damage", want - have)
        ctx.trait.applied = want
        ctx.applyStatus(ctx.unit, "status_wrath", { magnitude = want })
    end,
}
