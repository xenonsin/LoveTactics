-- Blood Money: greed made literal. A plain, modest swing on its own -- and then the miser opens the
-- purse mid-strike and every coin poured in lands as extra damage. It is the flagship of the rogue's
-- MONEY kit: abilities that spend the campaign's own gold (Combat.spendPurse, reached as fx.spendPurse)
-- as a combat resource, the player-side mirror of Aurea's gold-warded general at the end of the greed
-- line. No randomness -- wealth is the input and damage is the output, deterministically.
--
-- WHY IT IS GREED'S, and why coin is not a keyword. Every other rogue ability speaks a listed word --
-- guile, execute, blink, steal (docs/classes.md). This one speaks the SIN under all of them: the rogue's
-- shelf is greed, and greed's purest expression is not a technique, it is a wallet. So the header says
-- the borrow out loud the way the contract asks: the mechanic is the purse, and the purse is the shelf's
-- own point of view stated without a euphemism.
--
-- The shape is Asura Strike's (data/items/ability/ability_asura_strike.lua) with a purse where the chi
-- is: `fx.amount` is the floor the swing lands for when the purse is empty, and every coin the spend
-- draws is added on top. It pours up to a CAP -- the tuning knob -- and no further, so the decision the
-- item makes is "how deep is this shelf willing to let one blow reach into your bank", not "spend
-- everything you own on a rat". A broke party still swings; it just swings for the floor.
--
-- Outside the campaign there is no purse (a duel, a draft run get none -- states/battle.lua), so
-- fx.spendPurse takes 0 and this is exactly a modest stamina-priced jab. That is the intended inert
-- form, not a bug: the money is the campaign's currency, and where it is absent the ability is honest
-- about having nothing to spend.
local Curve = require("models.curve")

return {
    name = "Blood Money",
    description = "A modest strike, but it spends gold from your purse, and every coin lands as extra damage.",
    flavor = "He counted it out onto the table between them. Then he collected the table.",
    sprite = "assets/items/ability_blood_money.png",
    type = "ability",
    tags = { "physical", "guile" }, -- guile: the rogue's own word, so the shelf reads correct; the coin is the header's business
    class = "rogue",
    discipline = "mammonite", -- the purse is one earned shelf, not eight loose wares (data/disciplines/mammonite.lua)
    price = 660,
    -- Gated to the END of the greed line: on sale only once all ten Undercroft quests are cleared -- i.e.
    -- Aurea is beaten (slot 10). The money kit is the general of Greed's own art; you earn it by taking it
    -- off her. `Vendor.stock` unlocks at questsDone >= 10.
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 }, -- the swing still tires you; the purse is the OTHER cost
        damage = Curve.ramp(15, 25), -- fx.amount: the floor, before a single coin is spent
        description = "Spends up to your affordable pour of gold; each 5 gold adds 1 damage on top of the swing.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- The cap is the tuning knob: how far into the bank one blow may reach. It widens with the
            -- forge so a honed Blood Money can pour more, which is the honest thing to buy on this item --
            -- not a bigger floor, a bigger APPETITE. `spent` is what the purse could actually afford up to
            -- the cap (Combat.spendPurse clamps and hands back the real figure), so a thin wallet simply
            -- pours less. One coin in five becomes a point of damage.
            local cap = 100 + fx.level * 20
            local spent = fx.spendPurse(cap)
            fx.damage(t, { amount = fx.amount + math.floor(spent / 5) })
        end,
    },
}
