-- A mace, so it displaces (docs/weapons.md) -- and this one displaces in TIME rather than across the
-- board. The blow lifts its target off the field entirely (status_suspended): it cannot act, cannot be
-- acted on, and cannot answer, until it comes back down.
--
-- Quest-only: `class` with no `price`.
--
-- The family's premise says you are buying where they end up. Every other mace answers with a tile. This
-- answers with "nowhere, for a while", which is the same purchase carried to the only place it had left
-- to go -- and it is a strictly different tool, because a suspended body is not merely out of position,
-- it is out of the fight AND out of reach.
--
-- That second half is the cost, and it is severe: your party cannot touch it either. Suspending the
-- enemy champion means nobody is killing the enemy champion for those ticks. So it is never a burst
-- tool and always a tempo one -- take their heaviest hitter off the board while you finish the rest of
-- the line, or blank the one turn you know is going to land badly.
--
-- The obvious misuse, worth naming: suspending something the party had nearly killed. It comes back
-- whole in the sense that matters -- alive, and now with your whole party's cooldowns spent.
return {
    name = "Suspension Mace",
    description = "Lifts the target clean off the field: it cannot act, be acted on, or answer until it returns.",
    flavor = "Every other mace in the armoury is an argument about where. This one declined to have that argument.",
    sprite = "assets/items/suspension_mace.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5, -- the slowest mace on the rack: taking a body off the board is not a quick motion
        cost = { stat = "stamina", amount = 12 },
        -- The lowest damage of any mace but the Long Fall. It has to be: this is hard control, and hard
        -- control that also hit properly would be the only knight weapon anyone carried.
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9 },
        effect = function(fx)
            -- Strike FIRST, suspend second, and the order is load-bearing: a suspended body cannot be
            -- acted on, so a mace that lifted before it hit would never land its own blow.
            fx.damage(fx.target)
            if fx.target and fx.target.alive then
                fx.applyStatus(fx.target, "status_suspended")
            end
        end,
    },
}
