-- Incense: the drifting smoke a swung censer keeps around its bearer. Allies standing in it are Blessed
-- (data/status/status_blessing.lua). Laid as a square around the bearer by Combat.layIncense and lifted
-- again the instant they move, so unlike a banner's square this ground WALKS -- see the censer family in
-- docs/weapons.md.
--
-- Its own zone id, rather than reusing hazard_sacred which grants the same Blessing, for exactly the
-- reason each banner needs one (see data/hazards/hazard_rally.lua): a zone-bound status remembers the id
-- that granted it and asks "is a zone of THAT id still under me?". Share the id, and a Sacred Banner's
-- square would happily hold a Blessing alive under someone the censer had long since walked away from.
--
-- The bearer IS blessed by their own smoke, which is where this parts company with a banner. A standard
-- is an object holding ground open for other people and does not rally itself; a censer is carried, and
-- whoever swings it is standing in the middle of the cloud.
return {
    name = "Incense",
    description = "A censer's smoke: allies standing within are Blessed.",
    sprite = "assets/hazards/incense.png",
    tags = { "holy" },
    -- NOT a banner's 9999. Nothing is planted here -- this ground answers to a censer that is renewing
    -- it every beat (Combat.layIncense refreshes the cloud from Combat.rebase and Combat.enterTile). The
    -- short count is what makes that renewal load-bearing: lose the censer -- to a pickpocket, to a
    -- corpse -- and the smoke thins out and is gone within a turn instead of hanging on the field
    -- forever with nobody left to carry it.
    duration = 12,
    disposition = "friendly", -- an ally will step into it; the enemy gains nothing by standing here
    onEnter = function(ctx)
        if not ctx.isAlly(ctx.unit) then return end
        -- Blessing declares no `lingers`, so this grant is stamped with "hazard_incense" as its source
        -- automatically: it lasts exactly as long as the smoke is over the unit, and lifts the moment
        -- the censer walks off with it (Hazard.reap). You have to stay near the priest.
        ctx.applyStatus(ctx.unit, "status_blessing", { magnitude = ctx.amount })
    end,
}
