-- An imp's cinder spit: a lesser demon's own body (the `natural` family -- see models/item.lua), and
-- the reason the village lesson can be taught at all.
--
-- It strikes from TWO tiles and never from one, which is load-bearing rather than flavour. Parry
-- answers any blow struck from an adjacent tile, magical or not -- "a wand to the face is still a
-- melee strike", tests/counter_preview_spec.lua -- and an iron sword's parry deals more than an imp
-- has health. So an imp that walked up and clawed would be cut down by the very sword it swung at,
-- and the lesson needs both back-line imps ALIVE for the player to kill together
-- (data/tutorials/village.lua). Keeping their distance is how they survive to be the lesson.
return {
    name = "Cinder Spit",
    description = "Spits a mouthful of hellfire at a foe two tiles off.",
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
        cost = { stat = "stamina", amount = 5 },
        --        level:  0  1  2  3  4  5  6  7  8  9  10
        damage = { 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 12 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
