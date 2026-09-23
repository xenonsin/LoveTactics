-- THE PARTING KISS: the succubus line's own blow, and the Lust circle's THIRD displacement verb.
--
-- The stratum already had two and they are opposites pointed at one body: the talons haul you IN from
-- two tiles, the gust drives you OUT from three (data/characters/character_harpy.lua). This is neither.
-- **It trades.** She kisses whatever closed on her and the two of them change tiles -- she is standing
-- where you were, and you are standing where she was.
--
-- WHICH IS WHY IT IS REACH 1 AND NOT MORE, and the reason is the opposite of the talons'. A snatch
-- thrown from an adjacent tile moves nobody, so the talons had to buy a tile of reach before the verb
-- meant anything. A TRADE at reach 1 already moves two bodies -- and stays adjacent afterwards, which
-- is the whole of what makes it a different verb rather than a cheaper pull. Nobody is disengaged.
-- What changed is which side of the line each of them is on.
--
-- AND IN THE THINWALL KEEP THAT IS THE WHOLE FIGHT. The castle is a warren of rooms and doorways
-- (data/biomes/castle.lua). The body that reached her came from the company's side of the door; after
-- the kiss it is standing on HERS -- in the room with the flock, past the threshold its line was
-- holding, with nobody beside it. She has taken no ground and dealt very little, and one of you is now
-- alone in the middle of her floor. **The building does the rest**, exactly as it does for the gust.
--
-- SO IT PUNISHES CLOSING, which is what a thin body that does not want a brawl needs and what neither
-- of the circle's other two animals provides. A harpy holds the gap; a lamia wants you held beside it;
-- this one wants you to come, and makes the coming the mistake.
--
-- A DEMON'S BLOW BURNS (docs/bestiary.md, "...and a demon's blows burn"): `fire` is on the tag list and
-- the channel is NOT moved -- a physical blow with an element on it, so a coat still answers it and a
-- Salamander Hide is not dead weight against her the way it is against the gust.
--
-- THE TRADE IS GATED ON THE HIT, like every rider on this ground. A rider that could not miss riding a
-- blow that could is the shape of bug the whole circle was rebuilt out of once already
-- (docs/accuracy.md). A missed kiss moves nobody.
--
-- Combat.swapUnits springs whatever waits on BOTH tiles -- a trap, a hazard, the keep's own disarming
-- threshold -- exactly as a walk or a shove would. That belongs to the primitive and is deliberately
-- not restated here.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Parting Kiss",
    description = "Strikes an adjacent foe and trades places with it.",
    flavor = "Nobody has ever been able to say afterwards which of them moved.",
    sprite = "assets/items/parting_kiss.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "fire", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt > 0 and fx.target.alive then fx.swap(fx.target) end
        end,
    },
}
