-- Mistlight: the Nymph lights a foe, and the next shove that finds it throws it a tile further.
--
-- The rule is the status's (data/status/status_mistlit.lua, spent by Combat.knockback). It is the one
-- piece of her kit that is about somebody else's turn -- she marks, the flock throws -- which is why the
-- Dryad line lives in the Move half of the Lust circle and shares its fights with the harpies.
--
-- A light, not a blow: it deals nothing, so it has no hit to miss. A natural weapon: no class, no price,
-- noSteal (tests/bestiary_spec.lua).
return {
    -- Its own name and not the spell's (ability_mistlight): the wiki links a body's kit and its drops by
    -- name, and two items sharing one would point at each other's page (tests/wiki_spec.lua).
    name = "Wisp-Light",
    description = "Lights a foe: it cannot hide, and the next shove throws it one tile further.",
    flavor = "Travellers follow it off the road. Here, there is no road, and it is you being followed.",
    sprite = "assets/items/mistlight.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 6 },
        ai = {
            { priority = "normal", act = "cast", targetPref = "nearest",
              when = { subject = "any_foe", test = "lacks_status", value = "status_mistlit" } },
        },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_mistlit")
        end,
    },
}
