-- Off Luxuria's body (Descent.DROPS.lust): her escape, handed over. She trades places with one of her own
-- when a foe reaches her (models/court.lua); carried, it is a skirmisher's rescue -- pull a wounded body
-- out of a press and put a fresh one where it stood, across half the board.
--
-- A general's find: `unstocked`, on the skirmisher's shelf (the house of being somewhere else).
return {
    name = "Changing Partners",
    description = "Trade places with an ally up to 5 tiles away.",
    flavor = "She never once left the floor. She only ever changed who she was dancing with.",
    sprite = "assets/items/ability_changing_partners.png",
    type = "ability",
    tags = { "utility" },
    class = "skirmisher",
    unlockLevel = 13,
    unstocked = true,
    activeAbility = {
        target = "ally",
        range = 5,
        speed = 5,
        support = true, -- a rescue, not a strike
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            local ally = fx.target
            if not (ally and ally.alive) then return end
            if ally == fx.user or ally.side ~= fx.user.side then return end
            if not fx.swap(ally) then return end
            fx.log("action", string.format("%s changes partners with %s.",
                (fx.user.char and fx.user.char.name) or "The bearer",
                (ally.char and ally.char.name) or "an ally"), fx.user)
        end,
    },
}
