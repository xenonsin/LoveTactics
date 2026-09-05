-- A censer, so the smoke is the weapon (docs/weapons.md). Its cloud is hazard_grasping_hollow -- sucking
-- ground that roots whatever steps into it.
--
-- Quest-only: `class` with no `price`.
--
-- Ground that walks AND holds, which is a combination the family's own machinery makes strange. A censer's
-- cloud is lifted and laid again every time the bearer moves, so this is a root that follows the priest:
-- the tiles around them are always the tiles nobody can leave, and where those tiles are is a decision
-- the priest makes on foot rather than by casting.
--
-- What it produces is a body nobody can disengage from. Every skirmisher, every flanking rogue, every
-- caster trying to keep its distance has to solve the priest before it can solve anything else -- and the
-- priest is the least threatening thing on the board. It is the Cathedral's argument that presence is a
-- form of coercion.
--
-- Unsided, and this one bites hard: your own line is rooted in it exactly as readily, which means the
-- priest cannot simply walk into the middle of their own formation. Where the smoke goes has to be
-- chosen against your own people as well as theirs, and that is the discipline of the item.
local Curve = require("models.curve")

return {
    name = "Censer of the Grasping Hollow",
    description = "Inflicts Root on adjacent foes.",
    flavor = "The Cathedral's exorcists carried it. What they were exorcising was reportedly not in a hurry either.",
    sprite = "assets/items/censer_grasping_hollow.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "earth", "melee" },
    class = "priest",
    dropTier = 4,
    incense = {
        hazard = "hazard_grasping_hollow",
        radius = 1,
        amount = Curve.ramp(3, 13),
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
