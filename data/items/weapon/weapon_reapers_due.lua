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
return {
    name = "The Reaper's Due",
    description = "Cleaves a wide arc, landing harder for every foe you have already killed this battle.",
    flavor = "It is not a well-made axe. It is only an axe that has been used a great deal, and has opinions about that.",
    sprite = "assets/items/reapers_due.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        -- Below the iron axe's, and that is the FLOOR rather than the number: this is what it swings for
        -- on the opening turn, before the count has anything in it.
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9 },
        aoe = { shape = "front", width = 3 },
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
