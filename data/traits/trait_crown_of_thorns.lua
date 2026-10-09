-- CROWN OF THORNS: the Hollow Crown's want made to hurt the wanting (data/items/utility/utility_crown_of_thorns.lua;
-- slice D). A passive area, as the author asked: foes within 2 of the bearer lose a tenth of their max health each
-- time they use an ability.
--
-- AN ABILITY, NOT A SWING: an item of type `ability` -- a spell, a skill, a placed trap -- and never a weapon's blow or
-- a drunk draught, so the thorns price the clever thing and leave the plain one alone. A TOLL, not a blow: raw, past
-- armour, the way the Crown's own Last Hour lands, because "lose a tenth" is a share of the body and not a hit a
-- breastplate argues with. Heard through Trait.onAnyCast, after the working resolves.
return {
    name = "Crown of Thorns",
    description = "Foes within 2 of you lose a tenth of their max health each time they use an ability.",
    reach = 2,
    share = 0.1,
    onAnyCast = function(ctx)
        local u, caster, item = ctx.unit, ctx.caster, ctx.castItem
        if not (u and u.alive and caster and caster.alive and item) or caster.side == u.side then return end
        if item.type ~= "ability" then return end
        local Combat = require("models.combat")
        if Combat.unitGap(u, caster) > ctx.param("reach", 2) then return end
        local n = math.max(1, math.floor(Combat.unreservedMax(caster.char, "health") * ctx.param("share", 0.1)))
        Combat.dealFlatDamage(ctx.combat, caster, n, {}, "Crown of Thorns", u, { raw = true })
    end,
}
