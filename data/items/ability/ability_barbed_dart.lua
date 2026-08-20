-- Barbed Dart: a hunter's opening mark, thrown from range. It does little damage of its own -- the
-- point is the barb it leaves in, which opens the target to piercing: Vulnerable: Pierce
-- (data/status/status_vulnerable_pierce.lua), +8 from every pierce hit that follows.
--
-- On the hunter shelf because setup-then-payoff is gluttony's whole loop (docs/classes.md), and pierce
-- is what the shelf's bows and longbows deal -- mark the priority target from range, then the ranged
-- line drills it. It is the MOBILE answer the family was missing: Exposed already opens a foe to pierce,
-- but only inside a Coveted Blood cloud you have to keep standing in, which a bow line cannot use. See
-- docs/vulnerability.md for the family.
local Curve = require("models.curve")

return {
    name = "Barbed Dart",
    description = "Deals light piercing damage and inflicts Vulnerable: Pierce.",
    flavor = "You do not throw it to wound. You throw it so the arrows after it mean more.",
    sprite = "assets/items/ability_barbed_dart.png",
    type = "ability",
    tags = { "pierce", "physical", "ranged" },
    class = "hunter",
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(15, 25), -- light: the mark is the payload, not the dart
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_vulnerable_pierce" })
        end,
    },
}
