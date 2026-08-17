-- A glass-mote's shard: it takes what you built rather than what you have.
--
-- The Envy circle's swarm strips a buff and is worth nothing else. That is the setup for two different
-- payoffs standing behind it -- the Mimic, which throws back whatever was aimed at it, and Second Water,
-- whose reflection copies the WEAKEST body it can see. A party the motes have been stripping is a party
-- whose weakest body they chose.
--
-- So this is the rare swarm weapon that is not about damage at all. Killing motes is cheap; letting them
-- work decides what the rest of the floor does to you.
local Curve = require("models.curve")

return {
    name = "Glass Shard",
    description = "Cuts an adjacent foe and strips a blessing from it.",
    flavor = "It cannot make anything. It is extremely good at the other thing.",
    sprite = "assets/items/glass_shard.png",
    type = "weapon",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 3 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            fx.damage(fx.target)
            fx.dispelUnit(fx.target, 1) -- one blessing, which is all a mote is worth
        end,
    },
}
