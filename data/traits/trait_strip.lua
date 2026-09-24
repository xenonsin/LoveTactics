-- STRIP: the velvet slimes' rule (Lust's slime line). A blow the bearer lands with its weapon takes a
-- piece of the target's gear off them and into the slime, which wears it (Combat.strip): armour first,
-- then the weapon, then the rest. It is a loan for this fight only -- the piece comes home when the slime
-- dies, and at the end of the battle whatever happens (Combat.returnStripped, Character.restoreStripped).
--
-- LUST'S VERB, and neither half of the circle's hold/move rule: it roots nobody and shoves nobody, so it
-- may stand in any roster on the stratum. What it takes is not position but the company's say over
-- what it is wearing -- and "cut the one doing it" is literally how you get dressed again.
return {
    name = "Strip",
    description = "Its weapon blows take a piece of the target's gear, armour first, and it wears it.",
    -- `takes`, not `count`: a granter's traitParams reach every trait on the item, and the Queen's
    -- relic also carries Comes Apart, whose `count` is how many she divides into.
    takes = 1,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        if not (ctx.item and ctx.item.type == "weapon") then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not (target and target.alive) or target.side == ctx.unit.side then return end
        require("models.combat").strip(ctx.combat, ctx.unit, target, { count = ctx.param("takes", 1) })
    end,
}
