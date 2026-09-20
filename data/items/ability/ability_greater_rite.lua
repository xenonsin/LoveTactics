-- THE GREATER RITE: every binding in the company comes apart at once, and the company is standing in the
-- middle of it (models/curse.lua, docs/curses.md).
--
-- DENIED AS A UTILITY, REBUILT AS A WEAPON, and the rebuild is the design. A party-wide cleanse is
-- housekeeping; a party-wide cleanse that DETONATES is a cast whose power is loaded by how cursed you
-- have let yourself get. A clean company gets a slow, weak spell. A company four hexes deep gets the
-- biggest holy burst in the game.
--
-- WHICH PUTS THE EXORCIST IN THE SHAMAN'S ARGUMENT FROM THE OTHER SIDE. The counting shelf pays you to
-- carry curses; this pays you to carry them and then spend them all at once. Two disciplines wanting the
-- same thing for opposite reasons is the best possible shape for a mechanic to end up in, and neither
-- had to be told about the other.
--
-- CHANNELLED, because the engine already runs wind-ups and because a rite that costs turns is the field
-- reading of a rite that costs trips. The player chooses the depth (`windup` min/max), so holding it
-- longer is holding it while cursed -- which is exactly the risk the whole system is about.
--
-- IT IS THE ANSWER TO THE SPREADING LEFT ALONE. A company that has let the depth-14 hex run for three
-- floors walks into this with the biggest cast it will ever make, which is a story about a decision
-- rather than a punishment.
local Curve = require("models.curve")

return {
    name = "The Greater Rite",
    description = "Channelled: lifts every hex in the company, and each one bursts as it goes.",
    flavor = "The Cathedral does this over a month. He is proposing to do it before the next turn.",
    sprite = "assets/items/ability_greater_rite.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "exorcist",
    price = 740,
    unlockQuests = 8,
    activeAbility = {
        target = "self",
        range = 0,      -- a self-cast offers no reach to choose
        aoe = { radius = 2, shape = "square" },
        speed = 10,
        -- THE LIFT IS THE KINDNESS AND THE BURST IS THE CAST. Every unit the footprint actually
        -- damages is an enemy, so the band is hostile: a green ring here would tell the allies
        -- standing in it to move, when standing in it is exactly what they should be doing.
        support = false,
        windup = { min = 2, max = 4 },
        cost = { stat = "mana", amount = 18 },
        damage = Curve.ramp(16, 26),
        counter = function(unit)
            local Curse = require("models.curse")
            local combat = unit and unit.combat
            local n = 0
            for _, u in ipairs((combat and combat.units) or { unit }) do
                if u and u.alive and u.side == unit.side and u.char then
                    n = n + Curse.countOn(u.char)
                end
            end
            return n
        end,
        counterGates = false,
        counterLabel = "Hexes",
        description = "Lifts every hex in the company; the burst grows with how many came off.",
        effect = function(fx)
            local Curse = require("models.curse")
            local combat, user = fx.combat, fx.user
            local lifted = 0
            for _, u in ipairs((combat and combat.units) or {}) do
                if u.alive and u.side == user.side and u.char then
                    for _, item in ipairs(Curse.hexedOn(u.char)) do
                        Curse.lift(item)
                        lifted = lifted + 1
                    end
                end
            end
            -- 40% a binding. Steep, because the counter is one the player had to be brave to fill.
            for _, u in ipairs(fx.aoeUnits() or {}) do
                if u.side ~= user.side then
                    fx.damage(u, { amount = math.floor((fx.amount or 0) * (1 + 0.4 * lifted)),
                        tags = { "holy" } })
                end
            end
        end,
    },
}
