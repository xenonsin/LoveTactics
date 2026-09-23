-- Honeyed Ground: the Alraune pours sweetness on the floor around a foe, and the floor keeps it.
--
-- The cast is aimed at a body and lands on the diamond around it -- five tiles of hazard_honeyed_ground,
-- owned by her, so the honey dries the moment she falls. What the ground does is the status's
-- (data/status/status_honeyed.lua): it heals on arrival and puts a body to sleep if its turn ends there.
--
-- IT HURTS NOBODY, AND THAT IS NOT A MISSING NUMBER. A cast that healed the company it was aimed at
-- reads as a mistake until the second half lands -- the Mandrake roots the body where it stands, and the
-- Gallows Seed decides whom the healing was for. This is the bait. The other two files are the hook.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Honeyed Ground",
    description = "Pours honey around a foe: it heals whoever arrives, and puts to sleep whoever stays.",
    flavor = "It is the best thing anybody has eaten since they came down the stair. That is the point of it.",
    sprite = "assets/items/honeyed_ground.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 12 },
        aoe = { shape = "diamond", radius = 1 },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_honeyed_ground", { owner = fx.user, amount = 6 + fx.level })
            end
        end,
    },
}
