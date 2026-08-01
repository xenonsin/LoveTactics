-- The Cafe: the general store, and the one vendor that is not a class shelf. It stocks the
-- CLASSLESS priced goods -- the mundane traveler's supplies no sin claims (a torch, the boots of
-- speed) -- and RESELLS every `potion`, whichever house brews it. See models/vendor.lua's `general`
-- branch (Vendor.sells) and docs/classes.md ("The general store").
--
-- It has no sin and runs no quest line: nobody quests for the grocer's favour, so it gates nothing --
-- every ware is available from the first visit (Vendor.stock ignores unlockQuests for a general
-- store). That is the point of it -- the seven houses sell you an identity; the Cafe sells you a
-- torch and a health potion for the road.
return {
    name = "The Cafe",
    general = true, -- the general store: stocks classless goods, sells for no class of its own
    stockTags = { "potion" }, -- and resells anything tagged thus, whatever class brews it
    sprite = "assets/vendors/cafe.png", -- shopkeeper portrait; falls back to a placeholder
    description = "Everything the road needs and nothing the temple sells.",
}
