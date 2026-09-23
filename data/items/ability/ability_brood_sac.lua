-- BROOD SAC: the Egg Sac rebuilt for a player. Two Spiderlings hatch on your side, beside you, and stay
-- for about three turns; they bite with Poison, and when one falls the other feeds (utility_brood_hunger,
-- on the spiderling's own kit). Off the Larder Mother; a trophy, never on a counter.
local DURATION = 15 -- ticks: three turns at Status.TICKS_PER_TURN

return {
    name = "Brood Sac",
    description = "Hatch two Spiderlings beside you for three turns.",
    flavor = "It was never meant to be carried. It does not seem to mind.",
    sprite = "assets/items/ability_brood_sac.png",
    type = "ability",
    tags = { "beast", "summon" },
    class = "beastmaster",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "self",
        range = 0,
        support = true,
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        effect = function(fx)
            for _ = 1, 2 do
                local x, y = fx.openTileNear(fx.user.x, fx.user.y)
                if not x then break end
                fx.summon("character_spiderling", x, y, { noClaim = true, duration = DURATION })
            end
        end,
    },
}
