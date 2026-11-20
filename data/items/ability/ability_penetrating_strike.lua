-- Quick Jab: the fighter's Tempo builder (docs/engines.md). A weak hit that costs almost nothing and
-- almost no time. What it is for is the Tempo it banks: any action of speed 2 or less is a QUICK action
-- and adds one to the pool (Engine.afterCast's `quickAction` tally), and a walk throws the whole pool
-- away (`resetOn = "moved"`). So a fighter building Tempo plants its feet and jabs, and spends it on a
-- Cascade.
--
-- One pool with the Duelist's Tempo (the author's call): a Duelist carrying this banks from quick
-- actions as well as from pressing one foe, and Coup Droit spends either.
--
-- Reworked from Penetrating Strike (2026-11-18). The armour answer it was moved to the rogue's
-- Exsanguinate and the alchemist's Rime Draught; the id stays so a hire's rung-0 kit keeps its piece.
local Curve = require("models.curve")

return {
    name = "Quick Jab",
    description = "A quick, light hit. Builds 1 Tempo.",
    flavor = "The Colosseum teaches it first, and to everyone, so the crowd has something to watch.",
    sprite = "assets/items/ability_penetrating_strike.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "fighter",
    price = 80,
    unlockLevel = 2,
    charge = { key = "tempo", from = { "quickAction" }, max = 6, resetOn = "moved" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 1,
        cost = { stat = "stamina", amount = 3 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
