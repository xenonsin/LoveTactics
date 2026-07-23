-- Overcharge: the alchemist half of the Artificer (mage x alchemist). Feeds a jolt of reagent into a
-- friendly construct (or any ally) and Hastes it (data/status/status_hasted.lua) -- cheaper, faster
-- actions, so a sentry that would have fired once fires again before the enemy comes back around. The
-- faithful reading of "a construct acts twice" the turn economy supports: not a second turn granted, but
-- the timeline bent so the next one arrives almost at once. Pairs with Emplace Sentry.
return {
    name = "Overcharge",
    description = "Hastes a friendly construct or ally: its next actions come far sooner.",
    flavor = "The Crucible does not build them to last. It builds them to be worth overspending.",
    sprite = "assets/items/ability_overcharge.png",
    type = "ability",
    tags = { "utility" },
    class = "alchemist",
    discipline = "artificer", -- mage x alchemist; the Constructs mechanic's first stock
    price = 260,
    repRank = 3,
    activeAbility = {
        target = "ally",
        range = 2,
        speed = 3,
        support = true,
        cost = { stat = "stamina", amount = 5 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_hasted")
        end,
    },
}
