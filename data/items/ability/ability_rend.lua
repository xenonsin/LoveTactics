-- Rend: a heavy slashing blow that does not just cut but leaves the cut OPEN -- the struck foe is left
-- Vulnerable: Slash (data/status/status_vulnerable_slash.lua), taking +8 from every slashing hit that
-- follows. The strike that opens the wound is itself a slash, so a single fighter combos with their own
-- next swing, and a two-slasher line (twin greatswords, an axe and a duelist) turns the opener into a
-- rout.
--
-- On the fighter shelf because slash is wrath's own damage -- the axe-and-greatsword cluster is
-- fighter's (docs/classes.md) -- and because what this does with the wound is make the kill in front of
-- you land harder, which is what wrath is. The setup for the party, said in an axe's voice. First of the
-- Vulnerable openers; see docs/vulnerability.md for the family.
local Curve = require("models.curve")

return {
    name = "Rend",
    description = "Deals slashing damage and inflicts Vulnerable: Slash.",
    flavor = "The first cut is not the one that kills. It is the one that lets the next one in.",
    sprite = "assets/items/ability_rend.png",
    type = "ability",
    tags = { "slash", "physical", "melee" },
    class = "fighter",
    price = 240,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            -- The vulnerability rides the blow, so it is on the target the instant the wound is opened.
            fx.damage(fx.target, { inflicts = "status_vulnerable_slash" })
        end,
    },
}
