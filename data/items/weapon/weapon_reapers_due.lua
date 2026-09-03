-- An axe, so it cleaves (docs/weapons.md). Its extra is that it keeps a count: every kill its bearer has
-- taken this battle (the `kill` tally, Combat.tally) makes the whole arc land harder.
--
-- Quest-only: `class` with no `price`.
--
-- Where data/items/weapon/weapon_butchers_wedge.lua reads the crowd IN FRONT of the axe and this one
-- reads the crowd BEHIND it, which is the same sentence about being outnumbered pointed at a different
-- tense. The Wedge is best on the turn you are surrounded; the Due is best after you have stopped being.
-- A fighter carrying both has a weapon for the middle of the press and a weapon for the end of it.
--
-- It compounds with the family rather than against it, deliberately: an axe kills several things per
-- swing, so an axe is the weapon that fills this counter fastest. That is the point -- it is the one
-- scaling in the game whose own mechanic is what feeds it.
local Curve = require("models.curve")

return {
    name = "The Reaper's Due",
    description = "Increase damage by 25% per kill this battle.",
    flavor = "It is not a well-made axe. It is only an axe that has been used a great deal, and has opinions about that.",
    sprite = "assets/items/reapers_due.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    dropTier = 6,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        -- Below the iron axe's, and that is the FLOOR rather than the number: this is what it swings for
        -- on the opening turn, before the count has anything in it.
        damage = Curve.ramp(5, 15),
        aoe = { shape = "front", width = 3 },
        -- The count made visible, exactly as weapon_long_count wears its turn tally: the same `kill`
        -- number the effect below multiplies by, drawn on the slot and quoted in the tooltip. Without
        -- it the axe asks the player to hold the running total in their head to know what the next
        -- swing is worth -- and this one is uncapped, so the gap between the floor and the real number
        -- only widens as the fight goes on.
        --
        -- `counterGates = false`: a count of 0 is the opening turn, not a spent purse. The axe swings
        -- fine before it has killed anything; an empty count is the floor it grows from.
        counter = function(unit)
            return unit and unit.char and require("models.combat").tallyCount(unit, "kill") or 0
        end,
        counterGates = false,
        counterLabel = "Kills",
        effect = function(fx)
            local Combat = require("models.combat")
            -- +25% per kill, uncapped, applied to every body in the arc. Steeper per stack than
            -- weapon_long_count's turn counter because kills are far scarcer than turns and the fight
            -- may well end before this ever gets going.
            local kills = Combat.tallyCount(fx.user, "kill") or 0
            local scaled = math.floor((fx.amount or 0) * (1 + 0.25 * kills))
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u, { amount = scaled })
            end
        end,
    },
}
