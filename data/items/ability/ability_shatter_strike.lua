-- Shatter Strike: a heavy blow that breaks a held foe apart. Against a Frozen or Stunned target it
-- lands for double and CONSUMES the crowd-control (the ice shatters, the daze is spent) -- so it is a
-- burst finisher, not a way to keep a foe locked. Against anyone else it is a plain heavy hit.
-- Requires an adjacent melee weapon in the grid.
return {
    name = "Shatter Strike",
    description = "Doubles damage against a Frozen or Stunned foe, consuming it. Needs a melee weapon adjacent.",
    flavor = "A finisher, not a way to keep a foe held. You only get to spend the ice once.",
    sprite = "assets/items/ability_shatter_strike.png",
    type = "ability",
    tags = { "impact", "physical" }, -- `impact` is the blunt tag the game actually reads (see status_freeze)
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
            if fx.hasStatus(t, "status_freeze") or fx.hasStatus(t, "status_stun") then
                fx.damage(t, { amount = fx.amount * 2 })
                fx.clearStatus(t, "status_freeze")
                fx.clearStatus(t, "status_stun")
            else
                fx.damage(t)
            end
        end,
    },
}
