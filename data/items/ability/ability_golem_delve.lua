-- DELVE, AS A GOLEM WEARS IT (2026-09-25, "The Golems of Greed"). Not a second Delve: the review settled
-- that the golems carry the Delver's own (data/items/ability/ability_delve.lua), and this file hands them
-- that very ability -- the same `activeAbility` table, effect and all -- under the one change a creature
-- needs. The Delver's copy is a saboteur's trophy, and a creature may carry no shelf's stock
-- (tests/bestiary_spec.lua, "creatures carry no discipline gear"); so this is creature kit: noSteal,
-- unpriced, never dropped. What makes a golem's dive a golem's is `strikesVein` on its own body
-- (trait_strikes_vein), which the shared effect reads.
local delve = require("data.items.ability.ability_delve")

return {
    name = delve.name,
    description = delve.description,
    flavor = "The mountain does not dig. It simply stops being where it was.",
    sprite = delve.sprite,
    type = "ability",
    tags = delve.tags,
    class = "creature",
    noSteal = true,
    activeAbility = delve.activeAbility,
}
