-- Gleaning: the rod drinks the leavings of other people's workings. Every time anyone within sight of
-- it casts a spell -- friend or foe -- it banks a charge, and those charges are what its own active
-- spends (data/items/utility/utility_gleaning_rod.lua).
--
-- Rides Trait.onAnyCast, the broadcast hook, which is the only way an item can learn that somebody
-- ELSE did something. That is what makes this the strangest economy on the shelf: the rod is worth
-- nothing in a brawl between four fighters and enormous in a fight between two casting lines, and the
-- player finds out which fight they are in on the second turn rather than at the shop.
--
-- BOTH SIDES FEED IT, which is the mechanic and not a generosity. Gleaning off your own priest is the
-- reliable half (you control the timing) and gleaning off the enemy mage is the profitable half (you
-- do not). A rod carried beside your own caster is a slow steady drip; a rod carried into the Arcanum
-- is a full cup by the third turn.
--
-- Charges live on the ITEM (`ctx.trait.item.charges`), not on the unit: they are the rod's, so they
-- survive it being handed to somebody else and they do not follow its bearer onto a different relic.
-- Note `ctx.trait.item` rather than `ctx.item` -- on this hook the event's own `castItem` is what was
-- cast, and ctx.item is only reliable where the two cannot be confused (see Trait.onAnyCast).
return {
    name = "Gleaning",
    description = "Banks a charge whenever anyone nearby works a spell.",
    magnitude = 12, -- the ceiling: charges past this spill
    range = 4,
    onAnyCast = function(ctx)
        local rod = ctx.trait and ctx.trait.item
        local caster = ctx.caster
        if not (rod and caster and caster.alive) then return end
        -- Sorcery only. A thrown rock teaches the rod nothing, and a rod that filled off axe swings
        -- would be a charge meter rather than a comment on what kind of battle this is.
        if not require("models.combat").isMagicItem(ctx.castItem) then return end
        local dist = math.abs(caster.x - ctx.unit.x) + math.abs(caster.y - ctx.unit.y)
        if dist > (ctx.def.range or 4) then return end
        rod.charges = math.min((rod.charges or 0) + 1, ctx.def.magnitude or 12)
    end,
}
