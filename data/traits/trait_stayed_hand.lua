-- The Stayed Hand: when its wearer is cut down to nearly nothing, something intervenes -- every
-- affliction on them is stripped, and they are lifted out of the fight for a moment.
--
-- The insurance policy this game did not have. Last Stand and Survivor's Reflex both keep a body ALIVE
-- through the blow that would have ended it, which is genuinely useful and also frequently pointless:
-- surviving at 1 health in the middle of four enemies buys a turn that the next enemy takes away
-- again. This buys the thing that actually saves someone, which is being UNREACHABLE -- Suspended, so
-- nothing can aim at the wearer at all while it holds.
--
-- Priced at exactly what that is worth. The suspension costs the wearer their own next turn (it shoves
-- them down the order), the cleanse is spent whether or not there was anything worth cleansing, and
-- the whole thing is on a long cooldown so it is once a fight and not once a corner. A wearer saved by
-- it comes back down having lost tempo and gained nothing but distance -- which is the correct shape
-- for a thing that cannot be planned around.
--
-- Fires on onDamaged, which only ever sees a SURVIVOR (Trait.onDamaged is not called on a killing
-- blow), so this cannot catch someone on the way down -- it catches someone who is nearly there. That
-- is a real limitation and the item's description says so: a single blow big enough to kill outright
-- goes straight past it. The Stayed Hand answers attrition, not execution.
return {
    name = "The Stayed Hand",
    description = "At the edge of death, cleanses its wearer and lifts them out of reach.",
    magnitude = 0.25, -- the health fraction it watches for
    onDamaged = function(ctx)
        if ctx.onCooldown("stayed_hand") then return end
        local hp = ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.health
        if not hp or hp.max <= 0 then return end
        if (hp.current / hp.max) > (ctx.def.magnitude or 0.25) then return end
        ctx.setCooldown("stayed_hand", 60) -- ~12 turns: once a battle, in practice
        -- Cleanse first, then lift. The order matters: a Suspended unit is untargetable, and the
        -- cleanse is something being done TO the wearer -- doing it second would be doing it to
        -- somebody who is, by the letter of the status, not there to have it done to.
        local Combat = require("models.combat")
        Combat.cleanse(ctx.combat, ctx.unit)
        ctx.applyStatus(ctx.unit, "status_suspended")
        ctx.log("status", string.format("Something stays the hand over %s.",
            ctx.unit.char and ctx.unit.char.name or "Unit"), ctx.unit)
    end,
}
