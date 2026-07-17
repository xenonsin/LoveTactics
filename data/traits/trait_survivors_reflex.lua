-- Survivor's Reflex: the hand that reaches for the flask before the mind has finished registering the
-- wound. When a blow leaves its bearer under `threshold` of their health, they drink a healing potion
-- out of their own grid on the spot -- no turn, no initiative, no aiming.
--
-- The design tension it exists for: a healing potion is a TURN, and the turn is the reason it goes
-- undrunk. A player at 20% health who spends their action drinking has answered the damage and done
-- nothing about the thing dealing it, so they gamble on one more swing instead, and that is the swing
-- that kills them. This reflex takes the choice away in the one direction the player would have wanted
-- it taken anyway, and charges them the stock rather than the tempo.
--
-- So it is priced in what it spends rather than what it saves. It costs nothing to fire (the reflex
-- itself is free -- the potion is the price), and the cooldown is short, because the real limit is
-- how many flasks are in the satchel. Carry one and this saves you once. It cannot save you at all
-- once the stock is out, which is the honest failure mode: it makes potions matter more, not less.
--
-- Fires from onDamaged, so it sees only a SURVIVOR -- a blow that outright kills is not something a
-- draught was ever going to answer, and the bearer wants a Second Wind for that. The threshold check
-- reads the unreserved ceiling, so a caster whose max health is locked away by a reservation is
-- measured against the health it actually has rather than the health it used to have.
return {
    name = "Survivor's Reflex",
    description = "Bloodied by a blow, you drink a healing potion at once -- no turn spent.",
    magnitude = 6, -- ticks before the reflex can fire again
    threshold = 0.4, -- fires when the blow leaves the bearer below this share of max health
    onDamaged = function(ctx)
        local u = ctx.unit
        if ctx.onCooldown(ctx.trait.id) then return end
        local Combat = require("models.combat")
        local hp = u.char.stats.health
        local ceiling = Combat.unreservedMax(u.char, "health")
        if ceiling <= 0 or hp.current > ceiling * ctx.def.threshold then return end
        -- Cooldown last among the free gates, and only once a flask is actually found: a reflex that
        -- reached for a potion it did not have would go quiet for six ticks having done nothing.
        local flask = Combat.carriedRestorative(u, "health")
        if not flask then return end
        ctx.setCooldown(ctx.trait.id, ctx.def.magnitude or 0)
        ctx.log("action", string.format("%s reaches for a flask on reflex!",
            (u.char and u.char.name) or "Unit"))
        Combat.quaff(ctx.combat, u, flask)
    end,
}
