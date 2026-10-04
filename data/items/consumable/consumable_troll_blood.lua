-- TROLL BLOOD: the Troll's drop, on the Apothecary's shelf. Approved 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- The race's regrowth in a bottle (data/status/status_troll_blood.lua): the rest of the fight, a fifth of your
-- health back each turn unless fire or acid reached you since your last. A different item from the trolls' own
-- organ (utility_troll_blood, "Indifferent") on purpose -- the drinker regrows and still gets out of the way.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Troll Blood",
    description = "For the rest of the fight, regrow a fifth of your health each turn, unless fire or acid hit you since.",
    flavor = "It tastes of iron and pond. It keeps tasting of it for longer than seems reasonable.",
    sprite = "assets/items/consumable_troll_blood.png",
    type = "consumable",
    tags = { "draught", "restorative" },
    class = "apothecary",
    unlockLevel = 9,
    unstocked = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        consumesItem = true,
        effect = function(fx)
            fx.applyStatus(fx.user, "status_troll_blood")
        end,
    },
}
