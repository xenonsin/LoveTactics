-- LULL: Desidia's Drowse, cut down for a warden and turned on the other side only ("Sloth's Bestiary", slice G,
-- approved word for word). At the end of the round, every foe that did not move falls Asleep.
--
-- The round is the caster's own: the cast puts Lull on the warden (data/status/status_lull.lua), which notes how far
-- every foe has walked, and at the start of the warden's next turn the ones that have not walked a step go under. A
-- Warden's because the warden's whole trade is making the ground decide for the other side -- this makes standing
-- still on it the wrong answer.
--
-- An unstocked trophy on the seat's rung (floor 10), noSteal like every stair piece.
return {
    name = "Lull",
    description = "At the end of the round, every foe that did not move falls Asleep.",
    flavor = "The March is quiet tonight. It is very easy to stay where you are.",
    sprite = "assets/items/ability_lull.png",
    type = "ability",
    tags = { "arcane", "magical" },
    class = "warden",
    unlockLevel = 10,
    unstocked = true,
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        -- Centred on nobody it helps: it sleeps foes, so it must not preview as a kindness (Combat.isSupportAbility).
        support = false,
        effect = function(fx)
            fx.applyStatus(fx.user, "status_lull", { applier = fx.user })
        end,
    },
}
