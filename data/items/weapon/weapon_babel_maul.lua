-- BABEL MAUL: what the Tower-Giant drops (data/characters/character_tower_giant.lua; "Pride's Bestiary",
-- 2026-09-30). Its Ambition in a barbarian's hands: a stack at the end of each of the bearer's turns
-- (trait_ambition, the Giant's own), and the next hit that lands consumes every stack for +3 damage each.
-- Carried and never swung, it builds; swung every turn, it is a slow hammer that hits for one stack more.
--
-- A HAMMER, so it is ponderous (speed 7) and two-handed (docs/weapons.md) -- and like the Unspent Blow it
-- banks instead of stunning: the count is what the family's tempo buys here. The count lives on the unit as
-- status_ambition, so a fresh fight opens empty. An unstocked trophy on the seat's rung.
local Curve = require("models.curve")
local Status = require("models.status")

local PER_STACK = 3 -- added to the blow's power for every stack of Ambition consumed

return {
    name = "Babel Maul",
    description = "Gain a stack of Ambition each turn. Your next hit consumes them all: increase its damage by 3 for each.",
    flavor = "It was a builder's maul once. The building went up for longer than anyone had a word for.",
    sprite = "assets/items/weapon_babel_maul.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "barbarian",
    unlockLevel = 14,
    unstocked = true,
    traits = { "trait_ambition" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- ponderous, as every hammer is
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(23, 34), -- the slot-14 hammer line (Balance.magnitudeVerdict); the banked count rides on top
        -- The count on the slot badge and in the tooltip, so the one number this maul is about is never only
        -- in the log. `counterGates = false`: an empty count is a fresh maul, not a spent purse.
        counter = function(unit) return Status.stacksOf(unit, "status_ambition") end,
        counterLabel = "Ambition",
        counterGates = false,
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local stacks = Status.stacksOf(fx.user, "status_ambition")
            local dealt = fx.damage(t, { amount = (fx.amount or 0) + PER_STACK * stacks })
            if stacks > 0 and (dealt or 0) > 0 then fx.spendStacks(fx.user, "status_ambition", stacks) end
        end,
    },
}
