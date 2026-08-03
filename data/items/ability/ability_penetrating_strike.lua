-- Penetrating Strike: a blow aimed at the gap in the armor. It can only be thrown with a MELEE weapon
-- sitting adjacent to it in the 3x3 item grid (Combat.adjacencyMet gates the cast); the strike lands
-- as RAW damage -- its full Power ignores the target's defense and every tag resist (the `raw` flag in
-- Combat.mitigatedDamage), though a barrier still swallows it whole. The answer to a wall of plate.
local Curve = require("models.curve")

return {
    name = "Penetrating Strike",
    description = "Ignores armor and resistances entirely. Requires an adjacent melee weapon.",
    flavor = "The answer to a wall of plate, which the Colosseum keeps selling to the other side.",
    sprite = "assets/items/ability_penetrating_strike.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "fighter",
    price = 340,
    unlockQuests = 6,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(8, 18), -- lands whole: no defense or resist is subtracted (raw)
        requiresAdjacent = { type = "weapon", tag = "melee" }, -- a melee weapon must sit adjacent in the grid
        effect = function(fx)
            fx.damage(fx.target, { raw = true }) -- armor-piercing: skips defense + resists
        end,
    },
}
