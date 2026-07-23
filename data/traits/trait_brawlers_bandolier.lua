-- Brawler's Bandolier: the Warbrewer's passive (fighter x alchemist). Downing a draught in the middle of
-- a brawl buys the tempo back -- when the bearer casts a consumable, it gains Haste (data/status/
-- status_hasted.lua), so the turn spent drinking is very nearly a turn not spent. Fires from onCast,
-- where ctx.item is the CAST item, so it reads the drink's own tags. The faithful reading of "quaff as a
-- free action" that the turn economy actually supports: not free, but paid straight back.
return {
    name = "Brawler's Bandolier",
    description = "When you drink a draught, you gain Haste -- the tempo the drink cost, handed back.",
    onCast = function(ctx)
        local item = ctx.item
        local tags = (item and item.tags) or {}
        local drink = false
        for _, t in ipairs(tags) do
            if t == "restorative" or t == "potion" then drink = true break end
        end
        if not drink then return end
        ctx.applyStatus(ctx.unit, "status_hasted")
    end,
}
