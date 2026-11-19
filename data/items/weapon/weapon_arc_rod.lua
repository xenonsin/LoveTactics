-- Arc Rod: the alchemist's Reactions piece for lightning (docs/engines.md). A wand whose bolt jumps from
-- its target to every WET foe within three tiles of it, for half. Wet is laid by rain, by shallows, by a
-- lancer's soak or by a Bombardier's blast, and this is the wand that collects on it: the setup is the
-- party's, the payoff is the alchemist's. The mage's Conductor stays the long-range half.
--
-- A new item beside the Vitriol Wand, which keeps its Acid: it is the signature weapon of three bodies.
local Curve = require("models.curve")

return {
    name = "Arc Rod",
    description = "Its bolt jumps to every Wet foe within 3 tiles of the target, for half.",
    flavor = "Two copper rods and a jar of brine. The Crucible insists the brine is the clever part.",
    sprite = "assets/items/weapon_arc_rod.png",
    type = "weapon",
    tags = { "wand", "magical", "lightning", "ranged" },
    class = "alchemist",
    unlockLevel = 7,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line, as every wand's does
        speed = 3,
        cost = { stat = "mana", amount = 5 },
        damage = Curve.ramp(9, 19),
        arcReach = 3,
        effect = function(fx)
            local first = fx.target
            fx.damage(first)
            if not first then return end
            local half = math.max(1, math.floor((fx.amount or 0) / 2))
            for _, u in ipairs(fx.unitsNear(first.x or 0, first.y or 0, fx.item.activeAbility.arcReach or 3) or {}) do
                if u ~= first and u.alive and u.side ~= fx.user.side and fx.hasStatus(u, "status_wet") then
                    fx.damage(u, { amount = half })
                end
            end
        end,
    },
}
