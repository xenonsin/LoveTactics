-- SPIDER'S SUPPER: Liquefy as a coating. Adjacent weapons inflict Digesting on a hit (status_digesting):
-- Poison that heals whoever inflicted it, tick by tick -- the aura status carries the striker as its
-- applier (Combat's coatingOpts), which is what lets the venom know who to feed. Spent as the weapon
-- beside it is used, as every coating is. The one priced piece of the spider set: stock on the
-- Poisoner's shelf, and dropped by the brood.
local Curve = require("models.curve")

return {
    name = "Spider's Supper",
    description = "Adjacent weapons inflict Digesting on a hit, healing you as it works. Spent as they are used.",
    flavor = "The recipe is not a recipe. It is a list of things a spider did first.",
    sprite = "assets/items/consumable_spiders_supper.png",
    type = "consumable",
    tags = { "poison", "coating" },
    class = "poisoner",
    price = 180,
    unlockLevel = 4,
    maxStack = 4,
    aura = {
        appliesTo = { "weapon" },
        grantTags = { "poison" },
        status = { id = "status_digesting", opts = { duration = 25, magnitude = Curve.ramp(2, 12) } },
    },
}
