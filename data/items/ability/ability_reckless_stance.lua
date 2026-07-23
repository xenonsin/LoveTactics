-- Reckless Stance: stop guarding. Raised Damage, gutted defenses, for four turns
-- (data/status/status_reckless.lua).
--
-- Wrath's cheapest bargain and its most honest one. The shelf already sells health for damage twice --
-- Desperate Strike pays in a lump, Fury bets the whole bar -- and both are things you do at the moment
-- of crisis. This is the version you do at the START, before anybody has been hit, because you have
-- decided how this fight is going to go. "Wrath is what happens directly in front of you"
-- (docs/classes.md), and this is the item that makes sure something does.
--
-- Costs almost nothing and takes almost no time (speed 2), which is deliberate: the price is not the
-- stamina, it is the twenty ticks of standing there with no armor on. An ability whose whole cost is
-- its own effect does not need a second one.
--
-- It stacks with everything, in both directions. Blessing and an Elixir of the Giant pile onto the
-- damage; an Acid Bomb piles onto the hole in the defense, and a reckless fighter caught in one is
-- reading -22 to both defenses and about to find out what that means. That is the shape wrath should
-- have -- enormous and easy to punish.
--
-- Self-target only. Nobody else's guard is yours to drop, and a version that could be cast on the
-- party's mage would be a way to kill your own mage.
return {
    name = "Reckless Stance",
    description = "Drops your guard: raised Damage, far weaker defenses, for several turns.",
    flavor = "There is a way of fighting that assumes you will still be alive at the end of it. This is the other one.",
    sprite = "assets/items/ability_fury.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "impact" },
    class = "fighter",
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,      -- almost free in tempo: the cost of this ability is what it does to you
        support = true, -- it lands no damage of its own
        cost = { stat = "stamina", amount = 4 },
        effect = function(fx)
            -- Duration scales with the forge. The BONUS does not, and neither does the penalty: a
            -- better-kept blade does not make dropping your guard safer, it only makes you able to
            -- keep it dropped longer.
            fx.applyStatus(fx.user, "status_reckless", { duration = 20 + 2 * fx.level })
        end,
    },
}
