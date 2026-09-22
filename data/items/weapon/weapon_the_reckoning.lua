-- THE RECKONING: an honestly bad staff that becomes the heaviest thing in the company, on terms nobody
-- would choose (models/curse.lua, docs/curses.md).
--
-- +25% PER HEX THE BEARER CARRIES, read through `counter` with `counterGates = false` -- the pair The
-- Last Word wears to grow with every fallen ally. That pair is what puts the live figure on the grid
-- badge and in the tooltip, so the number the player reads and the number the swing is multiplied by are
-- the same call and can never drift.
--
-- ITS FLOOR IS THE POINT AND IT IS DELIBERATELY POOR. A clean company swings a staff's own feeble
-- damage, which should feel like carrying the wrong weapon. Four hexes doubles it -- and four hexes is a
-- body that can barely move, recovers nothing and has half a pool, which is the price that makes the
-- number safe. The scaling is paid for in exactly the place it is spent.
--
-- A STAFF, LIKE THE HEXBRAND, AND THAT IS NOT AN OVERSIGHT. The family contract is the reason: a staff's
-- swap IS the weapon and its strike is an afterthought (docs/weapons.md), which is the only family whose
-- promise survives a weapon that is bad most of the time. The two differ where it matters -- the
-- Hexbrand LAYS hexes and this one SPENDS them -- so a Shaman carrying both has a loop rather than a
-- duplicate.
local Curve = require("models.curve")

return {
    name = "The Reckoning",
    description = "Replaces Wait with Focus. Increase damage by 25% per hex the bearer carries.",
    flavor = "Light in a clean hand. Nobody who has held it says so twice.",
    sprite = "assets/items/the_reckoning.png",
    type = "weapon",
    tags = { "staff", "magical", "dark", "melee" },
    class = "shaman",
    unlockLevel = 7,
    waitBehavior = {
        kind = "focus",
        mana = Curve.ramp(6, 17),
        speed = 10,
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        counter = function(unit)
            return require("models.curse").countOn(unit and unit.char)
        end,
        counterGates = false,
        counterLabel = "Hexes",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local n = require("models.curse").countOn(fx.user and fx.user.char)
            fx.damage(t, { amount = math.floor((fx.amount or 0) * (1 + 0.25 * n)) })
        end,
    },
}
