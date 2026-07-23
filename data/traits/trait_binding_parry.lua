-- Binding Parry: the Duelist's Edge's answer, and a parry that declines to cut (docs/weapons.md).
-- Where data/traits/trait_parry.lua trades a blow for a blow, this one catches the attacker's blade and
-- will not give it back -- the swordsman answers by binding the two of them together (status_duelbound),
-- so whoever swung cannot walk away from the exchange they started.
--
-- Nothing is dealt. That is the whole shape of it: an ordinary parry punishes closing on a swordsman,
-- and this one punishes closing on a swordsman AND LEAVING. Against a foe that meant to trade anyway it
-- does very little; against a skirmisher who wanted one hit and a step back it is the answer to the
-- entire plan. A duelist's weapon in the literal sense -- it makes the fight a duel whether or not the
-- other party consented.
--
-- Declared `applies` rather than swinging, which is what keeps the hover preview honest: the branch in
-- Trait.counterPreview that reads `applies` quotes the status by name and no damage number, because
-- there is no damage. A reflex that both swung and applied would have to lie in one of the two.
return {
    name = "Binding Parry",
    description = "When struck by a foe your blade can reach, spend a swing's stamina to bind them in place instead of cutting back.",
    -- Same reach gate as the ordinary Parry (no `reach` declared, so the granting weapon's own band),
    -- and the same refusal to answer an answer -- two Duelist's Edges must not lock each other forever.
    counter = { applies = "status_duelbound" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.applyStatus(ctx.attacker, "status_duelbound")
        ctx.log("action", string.format("%s binds %s to the exchange!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"))
    end,
}
