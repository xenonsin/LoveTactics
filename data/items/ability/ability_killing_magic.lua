-- KILLING MAGIC: the Greater Archon's beam, and its drop (data/characters/character_greater_archon.lua; "The Crown's
-- Bestiary", slice A, 2026-10-09). A beam 5 tiles long that strikes every body in the line, its caster's own side
-- included, and passes through barriers (`throughBarrier`, read by Combat.mitigatedDamage and dealFlatDamage).
--
-- A lane cast, aimed at the adjacent tile as every lane cast in this engine is. The counter is the review's: do not
-- stand in a line with each other. The court's own Magical Barriers do not save its line from it either, so a
-- Greater Archon aiming through its own Lessers is a price the scorer weighs (it prices friendly fire).
--
-- A Mage's on the shelf, and the body carries the same piece: a humanoid may hold shelf stock (the Oni Priestess
-- carries her bell), so no creature copy is needed.
local Curve = require("models.curve")

return {
    name = "Killing Magic",
    description = "A beam 5 tiles long: magic damage to every body in the line, passing through barriers.",
    flavor = "The court does not argue with a ward. It was never asked to.",
    sprite = "assets/items/ability_killing_magic.png",
    type = "ability",
    tags = { "magical" },
    class = "mage",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        damage = Curve.ramp(16, 26),
        aoe = { shape = "line", length = 5 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then fx.damage(u, { throughBarrier = true }) end
            end
        end,
    },
}
