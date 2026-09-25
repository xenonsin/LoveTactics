-- The ground the Banner of the Mountain holds (data/items/ability/ability_banner_of_the_mountain.lua).
-- hazard_rally's shape: a friendly zone owned by the banner, gone when the banner falls. It grants Under
-- the Banner to DWARVES on the banner's side -- the colours mean nothing to anybody else.
return {
    name = "Banner of the Mountain",
    description = "Dwarves on the banner's side gain Under the Banner here.",
    tags = { "morale" },
    duration = 9999,
    disposition = "friendly",
    onEnter = function(ctx)
        if ctx.unit == ctx.hazard.owner or not ctx.isAlly(ctx.unit) then return end
        if not require("models.trait").has(ctx.unit, "trait_inheritance") then return end
        ctx.applyStatus(ctx.unit, "status_under_the_banner")
    end,
}
