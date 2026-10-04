-- HAG'S WEIGHT: the Mare's natural weapon ("Sloth's Bestiary", 2026-10-04, approved). It presses down on a body.
--
-- ON A SLEEPER IT CLIMBS ON: a blow on a body that is Asleep puts Hag-Ridden on it first (status_hag_ridden ties
-- the two together), so the blow itself does not wake it, and from then on the sleeper takes the Mare's damage at
-- the top of each of its turns (trait_hag_ridden, carried here). On a body awake it is only a blow.
--
-- `notOn`: the planner never swings it at the body it is already riding -- the ride is the wound there, and a free
-- second blow on a helpless body every turn is not what the review approved. A natural weapon: no class, no price.
local Curve = require("models.curve")

return {
    name = "Hag's Weight",
    description = "On a sleeping foe, rides it: blows do not wake it, and it takes this body's damage each turn.",
    flavor = "You wake up tired, and you do not know why. She does.",
    sprite = "assets/items/weapon_hags_weight.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    traits = { "trait_hag_ridden" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(6, 16),
        notOn = { "status_hag_ridden" },
        effect = function(fx)
            local u, tgt = fx.user, fx.target
            -- Through fx.applyStatus, so a hover preview mounts nobody: status_hag_ridden's onApply ties the two
            -- bodies together and puts Riding on the Mare, and the blow that follows lands on a ridden sleeper.
            if tgt and not u.ridingBody and not tgt.riddenBy and fx.hasStatus(tgt, "status_sleep") then
                fx.applyStatus(tgt, "status_hag_ridden")
            end
            fx.damage(tgt)
        end,
    },
}
