-- HEARTH HUNGER: cook it, then eat it. The bearer's WEAPON blows land harder on a Burning foe.
--
-- The Chimera's lion wears it at +4 (weapon_lions_maw) and its Battlemage drop at +3 (utility_hearth_hunger)
-- -- lower for a person, who picks when to cash the setup in, where the lion only ever bites whatever the
-- goat happened to reach. The magnitude is read through Trait.param so the granting item names its own.
--
-- WEAPON BLOWS ONLY (`ctx.blow`, the item throwing this blow), so a mage's own fireball does not pay itself
-- twice: the fire is the setup and a swing is the collection, which is the Battlemage's whole shelf --
-- "casts with the swing".
--
-- A PURE QUERY. Trait.outgoingDamageBonus runs this on every preview as well as every blow, so it must not
-- spend or mutate anything -- and because both paths sum it, the hover's number is the number that lands.
return {
    name = "Hearth Hunger",
    description = "Increase weapon damage against a Burning foe.",
    magnitude = 3,
    damageBonusVs = function(ctx)
        local blow = ctx.blow
        if not (blow and blow.type == "weapon") then return 0 end
        if not ctx.hasStatus(ctx.target, "status_burn") then return 0 end
        return ctx.param("magnitude", ctx.def.magnitude or 3)
    end,
}
