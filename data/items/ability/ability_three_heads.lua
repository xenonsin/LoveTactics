-- THREE HEADS: Cerberus's trophy ("The Crown's Bestiary", slice C, approved 2026-10-09). The dog's three bites for a
-- Vanguard: "Range 0. This turn, your attack strikes up to three different adjacent foes."
--
-- A breath before the blow, so it is FREE (no tempo, the turn stays open -- Overpower's and Surge's shape): it puts
-- Three Heads on the caster for this turn, and the next melee swing strikes the foe it was aimed at and up to two more
-- beside the caster, each its own blow (trait_three_heads). A Vanguard stands at the front of the line, which is where
-- three foes are adjacent at all. Unstocked: it is only ever carried out of the kennel.
return {
    name = "Three Heads",
    description = "Range 0. This turn, your attack strikes up to three different adjacent foes.",
    flavor = "Three mouths and one appetite. The trick is to have only the one.",
    sprite = "assets/items/ability_three_heads.png",
    type = "ability",
    tags = { "physical" },
    class = "vanguard",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_three_heads" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 0,      -- a breath bills no tempo of its own (cf. ability_overpower)
        free = true,    -- ...and leaves the turn open for the blow it buys
        support = true, -- it lands no damage itself
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            fx.applyStatus(fx.user, "status_three_heads")
        end,
    },
}
