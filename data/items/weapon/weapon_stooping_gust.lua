-- A stooping gust: the wing-beat of a harpy coming out of a dive, and the Lust circle's wind.
--
-- IT BARELY HURTS, AND THE KEEP DOES THE REST. One tile is nothing in open country; one tile in the
-- Thinwall Keep is through a doorway, round a corner, out of your healer's range, and very often
-- straight into a wall -- and Combat.knockback charges impact damage on a shove that is stopped,
-- harder the more travel it was denied. So the number on this blueprint is not what the gust is worth.
-- What it is worth is decided by the room, which is the whole argument of the Lust entry in
-- models/descent.lua: the flock does not kill a company, it rearranges one, and the building kills it.
--
-- REACH 3, AND SLOW. The flock holds the gap (`skirmish`), so this is what a harpy does with almost
-- every turn it takes; the talons are only what happens to whoever closes. Tempo is what the reach is
-- bought with, exactly as the briar lash buys its two tiles.
--
-- NO FIRE ON THE TAG LIST, where the talons carry it. Wind and fire arrive from different bodies on
-- this stratum -- a gust that also burned would make the Matriarch's cry a louder version of the
-- chaff's swing instead of the thing the chaff is softening you up for.
--
-- AND IT IS THE TALONS' OPPOSITE, WHICH IS THE FLOCK'S WHOLE SHAPE. The snatch hauls a body two tiles
-- IN; this drives one a tile OUT. A flock that only ever pulled would gather the company into a heap,
-- which is the one arrangement a party actually wants.
--
-- A MISSED STOOP MOVES NOBODY. `fx.damage` hands back what it actually dealt, and the shove is gated
-- on it: a rider that could not miss riding a blow that could is the shape of bug the whole circle was
-- rebuilt out of once already (docs/accuracy.md, and weapon_petal_touch's header).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Stooping Gust",
    description = "Beats a foe back a tile from reach. A collision hurts it.",
    flavor = "The wind off it is warm, and it smells of the inside of a church.",
    sprite = "assets/items/stooping_gust.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 5, -- slower than the talons' 3: the reach is bought with tempo
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            -- Straight away from the harpy -- the plain shove, which is what fx.knockback does with no
            -- destination handed to it. Everything about where that lands (a wall, a channel, a
            -- threshold, another body) belongs to the primitive and is deliberately not restated here.
            if dealt > 0 and fx.target.alive then fx.knockback(fx.target, 1) end
        end,
    },
}
