-- Whirlplate: articulated at the waist so its wearer can come all the way round without setting their
-- feet. Struck in melee, they turn with the blade out -- and everything adjacent takes it, not only
-- whoever swung (data/traits/trait_whirl_answer.lua).
--
-- THE ONLY AREA RETALIATION IN THE GAME. Every other counter in this catalog answers the hand that
-- reached in -- a parry, a riposte, thorns, a shield bash -- which makes every one of them worth
-- exactly one enemy however many are standing there. This answers the SITUATION, so its value is the
-- number of bodies around the wearer.
--
-- Which turns being surrounded from the thing that kills a fighter into the thing that pays them. That
-- is the same inversion `frenzy` performs for a swing (see castAmount in models/combat.lua), arriving
-- from the defensive side -- and the two are meant to be built together. A Crimson Greataxe and a
-- Whirlplate is a character who wants to be in the middle of five people and is right to want it.
--
-- Paced by the ordinary answer economy rather than a cooldown: each answer since the wearer last acted
-- costs double the one before (Trait.answerCost), so the second whirl in a round costs double and the
-- fourth runs them dry. That escalation is what keeps "surrounded by six" from being strictly better
-- than "surrounded by two" without a cap anybody had to write -- and the player watches it happen as a
-- stamina bar draining rather than as a hidden timer.
--
-- IT CUTS ALLIES STANDING ADJACENT. A whirl is a whirl, and a fighter in this plate is a fighter the
-- party's own line learns to leave a tile of room around.
local Curve = require("models.curve")

return {
    name = "Whirlplate",
    description = "On melee hit taken: cut every adjacent foe.",
    flavor = "The Colosseum's armourers charge extra for the hinge and nothing at all for the warning.",
    sprite = "assets/items/armor_whirlplate.png",
    type = "armor",
    tags = { "heavy" },
    class = "champion", -- fighter x knight; the Riposte-wall's plate -- answer every striker at once
    price = 575,
    unlockQuests = 6,
    traits = { "trait_whirl_answer" },
    bonus = { defense = Curve.ramp(3, 13), movement = -2 },
}
