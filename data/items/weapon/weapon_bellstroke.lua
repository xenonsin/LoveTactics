-- A bellstroke: the shove that rings a bell nobody is pulling, thrown at a body instead.
--
-- THE CIRCLE'S THESIS AT ITS LOUDEST. Every other shove on this ground is a nudge -- the harpy's gust
-- drives a body ONE tile and the blueprint says outright that the number on it is not what the gust is
-- worth, because the Thinwall Keep decides that (data/items/weapon/weapon_stooping_gust.lua). This is
-- the same argument with the volume turned up: three tiles, almost no damage of its own, and
-- Combat.knockback billing the impact of every tile the shove could not spend. In open country it is a
-- joke. In a warren of thin walls and doorways it is the wall doing the killing and the wind merely
-- choosing which wall.
--
-- SO THE FLOCK AND THIS ARE THE SAME VERB AT TWO SCALES, AND THE SCALE IS THE WHOLE DIFFERENCE. One
-- tile takes a body out of a rank; three takes it out of the ROOM -- through the doorway its line was
-- holding, into whatever the next chamber has in it, with the party's healer now on the wrong side of
-- a wall. A company learns the gust and thinks it has learned the stratum's wind; this is the version
-- where the lesson costs a body.
--
-- REACH 3 AND SLOW, matching the gust exactly, because a body that could do this from four tiles and
-- act again would never have to be answered at all. Tempo is what the reach is bought with -- the same
-- trade the gust and the briar lash both make.
--
-- NO FIRE ON THE TAG LIST, where the Whirl Elemental's own kit carries it in both hands. Wind and fire arrive
-- from different bodies on this stratum and meet in exactly one of them; the argument is
-- weapon_stooping_gust's and it holds harder here, since the whole point of the elite is that it is the
-- first thing on the floor doing both at once.
--
-- A MISSED STROKE MOVES NOBODY. `fx.damage` hands back what it actually dealt and the shove is gated on
-- it: a rider that could not miss riding a blow that could is the shape of bug the whole circle was
-- rebuilt out of once already (docs/accuracy.md).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Bellstroke",
    description = "Beats a foe back three tiles from reach. A collision hurts it.",
    flavor = "Upstairs the bell answers it. There has been nobody on the rope for a long time.",
    sprite = "assets/items/bellstroke.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 5, -- the gust's own tempo: the reach and the distance are bought with the turn
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            -- Straight away from the wind -- the plain shove, which is what fx.knockback does with no
            -- destination handed to it. Everything about where three tiles of that land (a wall, a
            -- threshold, a doorway, somebody else's back) belongs to the primitive and is deliberately
            -- not restated here.
            if dealt > 0 and fx.target.alive then fx.knockback(fx.target, 3) end
        end,
    },
}
