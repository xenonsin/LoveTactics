-- Shatter Strike: a heavy blow that breaks a held foe apart. Against a Frozen or Stunned target it
-- lands for double and CONSUMES the crowd-control (the ice shatters, the daze is spent) -- so it is a
-- burst finisher, not a way to keep a foe locked. Against anyone else it is a plain heavy hit.
-- Requires an adjacent melee weapon in the grid.
return {
    name = "Shatter Strike",
    description = "A heavy blow. Doubles its damage against a frozen or stunned foe, shattering the effect. Requires an adjacent melee weapon.",
    sprite = "assets/items/ability_shatter_strike.png",
    type = "ability",
    tags = { "crush", "physical" },
    class = "fighter",
    price = 260,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        requiresAdjacent = { type = "weapon", tag = "melee" },
        damage = { 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if fx.hasStatus(t, "freeze") or fx.hasStatus(t, "stun") then
                fx.damage(t, { amount = fx.amount * 2 })
                fx.clearStatus(t, "freeze")
                fx.clearStatus(t, "stun")
            else
                fx.damage(t)
            end
        end,
    },
}
