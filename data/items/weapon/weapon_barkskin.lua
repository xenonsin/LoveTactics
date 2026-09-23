-- Barkskin: the Dryad hardens an ally's skin to bark, and the next physical blow that finds it glances.
--
-- A Physical Barrier by another name (status_physical_barrier, one blow swallowed), because the ward the
-- game already has is exactly what bark does, and a second status saying the same thing would be a
-- second word for one mechanic. What makes it the grove's is who gets it: the Nymph that just planted,
-- the Hamadryad's escort, a harpy standing in the flock's line.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Barkskin",
    description = "Wards an ally: the next physical blow against it is negated.",
    flavor = "The yew is the longest-lived thing in any churchyard. Ask it how.",
    sprite = "assets/items/barkskin.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "protective" },
    noSteal = true,
    activeAbility = {
        target = "ally",
        range = 3,
        speed = 4,
        support = true,
        cost = { stat = "mana", amount = 8 },
        ai = {
            { priority = "normal", act = "support", targetPref = "nearest",
              when = { subject = "any_ally", test = "lacks_status", value = "status_physical_barrier" } },
        },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_physical_barrier", { magnitude = 1 })
        end,
    },
}
