-- ROUSE THE BINDING: the thing bound in the caster's own gear lashes out, and it lashes out harder the
-- worse it is (models/curse.lua, docs/curses.md).
--
-- THE ONLY ITEM IN THE GAME THAT READS A CURSE'S DEPTH. Every other counting piece asks HOW MANY hexes a
-- body carries; this asks HOW DEEP the worst one is -- a second axis the data has carried since the
-- first curse shipped and which nothing has ever used. It makes carrying one dreadful binding a
-- different build from carrying four mild ones, which is the distinction the count alone cannot draw.
--
-- SO IT IS THE ANCHOR'S PAYOFF. A body under The Anchor cannot move at all and is the worst thing in the
-- company to be holding -- and it is the best possible caster for this. A player who has been handed the
-- rift's cruellest hex and finds the shelf that wants it has had the system's best moment.
--
-- THE BINDING STAYS EXACTLY WHERE IT WAS, which is what keeps this inside the ruling: nothing is spent,
-- nothing is lifted, nothing moves. The spirit is woken and goes back to sleep.
local Curve = require("models.curve")

return {
    name = "Rouse the Binding",
    description = "Wakes the caster's worst hex to strike: increase damage by 15% per point of depth.",
    flavor = "It has been down there a long time and it is not pleased to be reminded where.",
    sprite = "assets/items/ability_rouse_the_binding.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "shaman",
    price = 520,
    unlockLevel = 10,
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 5,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(12, 22),
        counter = function(unit)
            local Curse = require("models.curse")
            local _, def = Curse.deepestOn(unit and unit.char)
            return def and Curse.depthOf(def) or 0
        end,
        counterGates = false,
        counterLabel = "Depth",
        description = "Increase damage by 15% for each point of depth on the caster's deepest hex.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local Curse = require("models.curse")
            local _, def = Curse.deepestOn(fx.user and fx.user.char)
            -- 15% a point of depth, so the rift's worst hex (14) is a little over double. Quoted off
            -- the same call the badge draws, so the figure and the blow cannot disagree.
            local depth = def and Curse.depthOf(def) or 0
            fx.damage(t, { amount = math.floor((fx.amount or 0) * (1 + 0.15 * depth)) })
        end,
    },
}
