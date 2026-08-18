-- An imp's cinder spit: a lesser demon's own body (the `natural` family -- see models/item.lua), and
-- the reason the village lesson can be taught at all.
--
-- It strikes from TWO tiles and never from one, which is load-bearing rather than flavour. Parry
-- answers any blow struck from an adjacent tile, magical or not -- "a wand to the face is still a
-- melee strike", tests/counter_preview_spec.lua -- and an iron sword's parry deals more than an imp
-- has health. So an imp that walked up and clawed would be cut down by the very sword it swung at,
-- and the lesson needs both back-line imps ALIVE for the player to kill together
-- (data/tutorials/village.lua). Keeping their distance is how they survive to be the lesson.
--
-- IT IS PAID FOR IN MANA, and that is the demon contract rather than a quirk of this one body: what
-- a demon's body does costs stamina, and what its WILL does costs mana (see
-- data/characters/character_demon_imp.lua). An imp is nothing but will -- hellfire is its whole
-- argument and it has no other -- so every shot it takes comes out of the purple bar, and it carries
-- stamina only for the punch it throws once the fire is gone.
--
-- Mana does not regenerate in this game (Combat.regenerate), so the pool behind this is a SHOT COUNT
-- and not a resource: an imp gets exactly six of these and then it is a body with claws. That is what
-- makes Drain Mana (data/items/ability/ability_drain_mana.lua) a real answer to a horde rather than a
-- rogue trick with nothing to bite on -- a siphon off an imp is two shots it will never take.
local Curve = require("models.curve")

return {
    name = "Cinder Spit",
    description = "Spits hellfire at a foe.",
    flavor = "A lesser demon's whole argument, and it makes it from as far back as it can.",
    sprite = "assets/items/cinder_spit.png",
    type = "weapon",
    -- `magical` routes the damage through magicDamage/magicDefense; `natural` is the family (a
    -- creature's body, never sold and never stolen), and the only archetype tag here.
    tags = { "natural", "fire", "magical" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 2,
        minRange = 2, -- never point-blank: an imp that closes is an imp that gets parried
        speed = 4,    -- slower than a swordsman: the party opens every exchange
        cost = { stat = "mana", amount = 5 }, -- hellfire is drawn from the will, not the arm
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
