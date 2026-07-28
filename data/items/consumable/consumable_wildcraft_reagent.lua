-- Wildcraft Reagent: not a shop item. This is what the Herbalist's field crafting PRODUCES -- Distil
-- wrings it out of a hazard, the Culler's Kit renders it off a body -- and it exists as a blueprint only
-- so that what you make is a real item rather than a special case.
--
-- Unpriced and classless, so no vendor stocks it and Spoils.lootCandidates cannot roll it: the only way
-- into a grid is to have brewed it (Combat.grantItem, which stamps `ephemeral` on the instance so it is
-- stripped at the gate). That is the whole reason it can afford to be generous -- it is never bought,
-- never sold, and never leaves the field it was made on.
--
-- Deliberately one reagent rather than a family of them keyed to the hazard it came from. A fire yields
-- the same vial as quicksand does, because the interesting decision is WHEN to spend a turn brewing and
-- what to throw away to carry it -- not which of nine colours the cauldron produced. If the shelf ever
-- wants elemental reagents they are cheap to add; what would not be cheap is un-adding them.
return {
    name = "Wildcraft Reagent",
    description = "Mends an ally and cleanses their afflictions.",
    flavor = "Whatever the ground was doing, it was doing it very vigorously. That is most of herbalism.",
    sprite = "assets/items/consumable_wildcraft_reagent.png",
    type = "consumable",
    tags = { "draught", "restorative" },
    ephemeral = true, -- belt and braces: the grant stamps the instance too
    maxStack = 5,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 2,
        consumesItem = true,
        healing = { 18, 18, 20, 20, 22, 22, 24, 24, 26, 26, 28 },
        description = "Mends an ally and cleanses their afflictions.",
        effect = function(fx)
            fx.heal(fx.target, fx.amount)
            fx.cleanse(fx.target)
        end,
    },
}
