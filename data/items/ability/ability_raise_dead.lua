-- Raise Dead: the mage's necromancy. It sweeps a 3x3 area for corpses (any fallen "real" unit left on
-- the field -- see Combat's corpse system) and reanimates each as a Zombie on your side. The zombies
-- fight the enemy for you but take their own turns (AI-run) -- allied in allegiance, not in command --
-- and rot away on a timer. Consumes each body, so a corpse can be raised only once, and a raised zombie
-- leaves no corpse of its own.
--
-- Requires nearby corpses: aim it where units have fallen. With no bodies in the blast it simply wastes
-- the turn (there is nothing to raise), so hold it until the field is bloodied.
return {
    name = "Raise Dead",
    description = "Raise every corpse in the area as a zombie that fights for you (but obeys no orders).",
    sprite = "assets/items/ability_raise_dead.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "mage",
    price = 500,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        support = true, -- raising your dead is a friendly act: preview green
        range = 3,
        speed = 6,
        cost = { stat = "mana", amount = 16 },
        aoe = { radius = 1, shape = "square" }, -- sweeps a 3x3 for bodies
        effect = function(fx)
            for _, corpse in ipairs(fx.corpsesIn()) do
                fx.raise(corpse, "zombie", { duration = 30 })
            end
        end,
    },
}
