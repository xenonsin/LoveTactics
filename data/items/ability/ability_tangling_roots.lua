-- Tangling Roots: the ground erupts under a foe, tearing at it and then seizing it fast. Deals modest
-- magical damage and leaves the target Rooted (data/status/root.lua) -- unable to move on its turn and
-- still burning time as if it had walked. The mage's answer to a charging bruiser: pin it out in the
-- open where the party can whittle it down. Scales with magic.
return {
    name = "Tangling Roots",
    description = "Snare a foe in grasping roots: light damage, and it cannot move for a time.",
    sprite = "assets/items/ability_tangling_roots.png",
    type = "ability",
    tags = { "nature", "magical" },
    class = "mage",
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- the roots have to reach a foe you can see
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        damage = { 5, 6, 6, 7, 7, 8, 9, 9, 10, 10, 11 }, -- light: the root is the payload, not the hit
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "root")
        end,
    },
}
