-- Wyrm's Venom: the Gilt Wyrm's breath, taken home (data/characters/character_gilt_wyrm.lua), reviewed
-- 2026-09-25. The same cone as the wyrm's own (data/items/ability/ability_venom_breath.lua): every foe in it
-- is poisoned, and the ground is left as Choking Fumes (data/hazards/hazard_choking.lua) for three turns --
-- laid on the caster's side, so it never chokes the company that breathed it. The strike is priced at the
-- power its rung names (tests/balance_spec.lua); the ground left behind is what the cone adds on top.
local Curve = require("models.curve")

-- Three turns at Status.TICKS_PER_TURN.
local FUMES = 15

return {
    name = "Wyrm's Venom",
    description = "Breathes a cone of venom: every foe caught is poisoned, and the ground chokes for 3 turns.",
    flavor = "Collected from the glands with a long spoon and a short prayer. It still remembers what it was for.",
    sprite = "assets/items/ability_wyrms_venom.png",
    type = "ability",
    tags = { "poison", "magical" },
    class = "poisoner",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 5,
        cooldown = 15,
        cost = { stat = "mana", amount = 8 },
        aoe = { shape = "cone", length = 3 },
        damage = Curve.ramp(16, 26),
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
