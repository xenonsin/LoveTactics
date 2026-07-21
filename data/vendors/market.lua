-- The Market: the general store, and the one vendor that is not a class shelf. It stocks the
-- CLASSLESS priced goods -- the mundane traveler's supplies no sin claims (a torch, the boots of
-- speed) -- and RESELLS every `potion`, whichever house brews it. See models/vendor.lua's `general`
-- branch (Vendor.sells) and docs/classes.md ("The general store").
--
-- It has no sin and no reputation ladder: nobody quests for the grocer's favour, so its standing
-- never moves off the entry rung and every ware is available from the first visit (Vendor.stock
-- ignores repRank for a general store). That is the point of it -- the seven houses sell you an
-- identity; the Market sells you a torch and a health potion for the road.
return {
    name = "The Market",
    general = true, -- the general store: stocks classless goods, sells for no class of its own
    stockTags = { "potion" }, -- and resells anything tagged thus, whatever class brews it
    sprite = "assets/vendors/market.png", -- shopkeeper portrait; falls back to a placeholder
    description = "Everything the road needs and nothing the temple sells.",
    -- A single rung: standing here is a formality, so there is nothing to climb.
    ranks = { 0 },
    rankNames = { "Patron" },
}
