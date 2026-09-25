-- Venom Breath: the Gilt Wyrm's own (data/characters/character_gilt_wyrm.lua). Poison, not fire -- the saga
-- has Fafnir breathe venom over the path, and fire is Avaritia's.
--
-- Every foe in the cone is struck and poisoned, and the cone is left full of CHOKING FUMES
-- (data/hazards/hazard_choking.lua) for three turns: the existing poison ground, reused on review ("don't we
-- already have a poison hazard? reuse that"). Laid on the breather's own side, so it chokes the company and
-- never the dwarves still standing beside the wyrm. The player's copy is ability_wyrms_venom.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

-- Three turns at Status.TICKS_PER_TURN.
local FUMES = 15

return {
    name = "Venom Breath",
    description = "Breathes a cone of venom: every foe caught is poisoned, and the ground chokes for 3 turns.",
    flavor = "It was a dwarf this morning. Whatever it breathes now, it did not learn in the mines.",
    sprite = "assets/items/ability_venom_breath.png",
    type = "ability",
    tags = { "poison", "magical", "breath" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 5,
        cooldown = 15,
        cost = { stat = "stamina", amount = 6 },
        aoe = { shape = "cone", length = 3 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u, { inflicts = "status_poison" }) end
            end
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_choking", { duration = FUMES, amount = 3 + fx.level })
            end
        end,
    },
}
