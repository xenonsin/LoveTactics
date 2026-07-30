-- Bitterroot Draught: the Herbalist's own answer to bad ground (hunter x alchemist). Cleanses what ails
-- you and leaves you proof against the hazard you are standing in.
--
-- The shelf's third leg, and the only one that is not about making things. Distil takes ground away and
-- the Culler's Kit takes bodies apart; this is what a herbalist drinks when the ground has already
-- happened to them. A discipline built on standing in weather needs one item that is simply about
-- surviving weather.
--
-- The immunity is deliberately short and deliberately general -- it is the drinker who becomes proof,
-- not the tile that becomes safe -- so it buys a crossing rather than an occupation. A herbalist who
-- wants to LIVE in the fire distils it instead.
--
-- Not tagged `potion`: the Market resells that tag and ignores standing, which would put a gated
-- discipline draught on the grocer's shelf turn one (docs/classes.md).
return {
    name = "Bitterroot Draught",
    description = "Cleanses your afflictions and proofs you against hazards.",
    flavor = "It tastes the way the ground smells. That is not a coincidence and it is not an accident.",
    sprite = "assets/items/consumable_bitterroot_draught.png",
    type = "consumable",
    tags = { "draught", "restorative" },
    class = "alchemist",
    discipline = "herbalist",
    price = 120,
    unlockQuests = 6,
    maxStack = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        consumesItem = true,
        description = "Cleanses you and proofs you against hazards.",
        effect = function(fx)
            fx.cleanse(fx.user)
            fx.applyStatus(fx.user, "status_regen")
        end,
    },
}
