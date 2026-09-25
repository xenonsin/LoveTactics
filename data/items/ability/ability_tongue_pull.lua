-- TONGUE PULL: the Giant Toad's Pull, and it IS the Pull -- same aim, same haul, same flier brought down
-- (data/items/ability/ability_pull.lua), read straight off that blueprint rather than copied, so the two
-- can never drift. Settled on review 2026-09-25: "have tongue reuse pull".
--
-- WHY A SECOND ITEM AT ALL: a creature carries only creature kit (tests/bestiary_spec.lua -- "a wolf is not
-- a Beastmaster; a wolf is what a Beastmaster has"), and the shelf Pull is bulwark stock. So the toad
-- carries this -- unpriced, noSteal, outside every shelf -- and the verb underneath is the knight's.
--
-- It is also what Gula takes when she eats one (character_giant_toad's `palate`): the one beast in the wood
-- that hands her a way to FETCH what she means to eat.
local Pull = require("data.items.ability.ability_pull")

return {
    name = "Tongue Pull",
    description = Pull.description,
    flavor = "It does not come to the meal. The meal comes to it, and does not get to decide.",
    sprite = "assets/items/ability_tongue_pull.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "impact", "physical" },
    noSteal = true,
    activeAbility = Pull.activeAbility,
}
