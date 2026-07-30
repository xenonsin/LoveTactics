-- Culler's Kit: the hunter half of the Herbalist (hunter x alchemist). Anything you kill leaves a
-- reagent in your satchel.
--
-- The literal fusion: the hunter kills it, the alchemist renders it down. It replaced a Forager's
-- Satchel that brewed from hazards, which the author correctly called out as conflicting with Distil --
-- two items reading the same source is one item with a spare. This reads BODIES, and the two sources
-- never overlap.
--
-- It pays out on any kill by any means, because `lastAttacker` is stamped by whatever did the killing:
-- an arrow, a poison tick, a trap you set three turns ago, a summoned wolf's teeth. That is right for a
-- discipline whose whole premise is that the fight is the ingredient -- a herbalist should not have to
-- land the last blow personally to be a herbalist.
--
-- Summons are worth nothing. A conjuration renders down to exactly what it was made of.
--
-- What you make evaporates at the gate (Combat.releaseClaims). Free potions that survived the battle
-- would make this a business rather than a build.
return {
    name = "Culler's Kit",
    description = "Every enemy you fell leaves a field reagent in your satchel.",
    flavor = "Nothing is wasted. She is very clear that this is a virtue and not an appetite.",
    sprite = "assets/items/utility_cullers_kit.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    discipline = "herbalist",
    price = 400,
    unlockQuests = 10,
    traits = { "trait_cullers_kit" },
}
