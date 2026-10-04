-- THE DUE'S CLAWS: what climbs out of a fallen Tollkeeper uses (data/characters/character_the_due.lua). Quick and
-- light: the Due is small and fast, and what makes it dangerous is who it goes for (models/toll.lua).
--
-- PAID IN FULL: a blow that lands on the body it was owed by is the debt collected, and the Due is gone
-- (fx.expendSelf, a dismissal: nothing struck it, so nothing climbs out of it). Kill it first, or take the blow.
-- A Due with no debtor -- its keeper fell to a burn, a trap, a hazard -- has nothing to collect and simply fights.
-- A demon's blow burns (docs/bestiary.md). Unstealable, on no shelf.
local Curve = require("models.curve")

return {
    name = "Due's Claws",
    description = "Rakes an adjacent foe. A blow on the foe it is owed by pays the debt, and it is gone.",
    flavor = "It knows exactly what it is owed, and by whom, and it has not been told either.",
    sprite = "assets/items/weapon_dues_claws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "claw", "slash", "physical", "melee", "fire" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            local user = fx.user
            if user and user.dueTarget and fx.target == user.dueTarget and (dealt or 0) > 0 then
                fx.expendSelf(string.format("%s collects what it was owed, and is gone.",
                    (user.char and user.char.name) or "The Due"))
            end
        end,
    },
}
