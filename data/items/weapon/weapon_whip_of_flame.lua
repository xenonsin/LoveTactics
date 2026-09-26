-- THE WHIP OF FLAME: the Thing Under the Seam's lash, rebuilt for a person (character_deep_bane's trophy,
-- approved on review 2026-09-26). Reach 2, it Burns what it hits, and it pulls that body one tile toward
-- you.
--
-- A MACE, BECAUSE THERE IS NO WHIP FAMILY. The review asked for "a weapon in the whip family"; the game has
-- none, and a family is ten weapons and a contract (tests/weapon_spec.lua), not a tag. What the whip DOES
-- is displace, and the mace is the family whose premise is exactly that -- "you are not buying the damage,
-- you are buying where they end up" (docs/weapons.md). It displaces the wrong way on purpose, as the
-- Gathering Bell already does, and at the Bell's reach: from two tiles out, the full haul IS one tile.
-- Both the Bell and this answer an argument the rest of the rack does not -- everything the party prices
-- around adjacency wants the enemy gathered.
--
-- What it adds over the Bell is the fire, and the fire is the point: the Burn rides inside the blow (a
-- lash that missed burned nothing), and a body dragged across burning ground takes that ground too.
-- Carried beside a trail that sets the floor alight, it is the body's own loop in a person's hands.
--
-- A trophy: `unstocked`, on the Bastion's rack and never sold (tests/discovery_spec.lua's TROPHIES).
-- Physical with `fire` on it, the demon's own blow, never moved to `magical`.
local Curve = require("models.curve")

return {
    name = "Whip of Flame",
    description = "Lashes a foe up to 2 tiles away, Burns it and pulls it a tile toward you.",
    flavor = "It does not need a hand to hold it. It has simply agreed, for now, to be held.",
    sprite = "assets/items/weapon_whip_of_flame.png",
    type = "weapon",
    tags = { "mace", "slash", "physical", "fire", "melee" },
    class = "knight",
    -- PLACED BY HAND at the floor it falls on (the thing stands on Greed's seat, floor six), not at the
    -- grader's 12: the grader prices the pull and the Burn as two riders on a mace, and a trophy's rung is
    -- where its body stands.
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 2, -- the Bell's reach: a lash has to be able to fetch something
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(11, 21),
        effect = function(fx)
            local dealt = fx.damage(fx.target, { inflicts = "status_burn" })
            -- Pulled AFTER the blow and only on a hit, as the Bell pulls: a corpse is not dragged, and a
            -- lash that missed caught nothing.
            if dealt and dealt > 0 and fx.target.alive then fx.pull(fx.target) end
        end,
    },
}
