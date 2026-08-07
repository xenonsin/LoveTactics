-- Benediction: the healing half of the Theurge's channelled miracle (mage x priest). A wind-up that
-- breaks over the whole party at once, and heals harder for every tick it was held.
--
-- The Long Prayer is this fusion pointed at ground; this is it pointed at bodies. Together they are the
-- discipline's argument -- that the answer to "what is a caster who is also a priest" is neither a
-- bigger heal nor a longer zone, it is a party that can be repaired in one motion by somebody willing
-- to spend two turns on it.
--
-- Field-wide rather than aimed, which is the whole reason it is worth a channel. A single-target heal
-- that took two turns to arrive would simply be a worse heal; one that reaches every ally wherever they
-- are standing is a thing no other shelf sells, and it is why the Theurge is the discipline you build
-- when the party has stopped being able to stay together.
--
-- Scales off fx.windup, so an interrupted prayer still heals -- less, but the mana is not wasted. Pair
-- it with the Vigil Beads and the wind-up becomes a promise rather than a hope.
local Curve = require("models.curve")

return {
    name = "Benediction",
    description = "Channeled: heals every ally. Increase healing for each tick held.",
    flavor = "It is not addressed to any of them. That is why it reaches all of them.",
    sprite = "assets/items/ability_benediction.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "theurge",
    price = 680,
    unlockQuests = 10,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        windup = 3,
        support = true,
        cost = { stat = "mana", amount = 18 },
        healing = Curve.ramp(10, 23), -- Combat.abilityMagnitude reads this
        description = "Channeled: heals every ally, more for the wind-up held.",
        effect = function(fx)
            local heal = fx.amount + (fx.windup or 0) * 4
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.side == fx.user.side then fx.heal(u, heal) end
            end
        end,
    },
}
