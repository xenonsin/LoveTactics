-- Asura Strike: everything the monk has gathered, spent at once, into one body. Damage is a modest base
-- plus SIX per chi held (Combat.chi), and the cast empties the pool outright -- all of it, including any
-- overflow past the cap, so there is never a hidden remainder left behind to start the next one early.
--
-- The chi ceiling (Combat.CHI_MAX, 10) is what keeps this honest. Without a cap the correct play in any
-- long fight would be to punch for nine turns and delete something on the tenth, which makes every turn
-- but the last one a formality. With it, the pool tops out, further punches on a full pool are WASTED,
-- and the monk is pushed to spend and rebuild rather than hoard -- so the decision the item really sells
-- is *when*, not *whether*.
--
-- Opened by holding any chi at all (one banked punch), so it is always available as a small blow and
-- only devastating when earned. That is the shape a dump should have: never dead, rarely maximal.
--
-- It is an ABILITY rather than a fist, so it does not read the `unarmedBonus` charms the way Flurry's
-- sub-strikes do -- its scaling is the chi, and stacking both would pay the monk twice for the same
-- punches. See ability_flurry.lua for the other half of the cycle, and for why the gate is a pure
-- `when` predicate over the shared pool rather than a counted per-item unlock.
local Curve = require("models.curve")

return {
    name = "Asura Strike",
    description = "Consume all your chi in one blow. Increase damage by 6 per chi.",
    flavor = "He had been counting since the door closed. He stopped counting.",
    sprite = "assets/items/ability_asura_strike.png",
    type = "ability",
    tags = { "fist", "physical" },
    class = "priest",
    discipline = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    price = 460,
    unlockQuests = 11,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- the slowest thing on the shelf: a blow this size is telegraphed
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(6, 16), -- fx.amount: the floor, before the chi
        unlock = {
            when = function(unit) return require("models.combat").chi(unit) >= 1 end,
            text = "Gather chi",
        },
        description = "Consume all chi at once. Increase damage by 6 per chi.",
        effect = function(fx)
            -- Takes the whole pool and reports what it took, so the blow is scaled by exactly what was
            -- spent. Inert in a dry run (it reports without draining), which is what lets the damage
            -- preview show the real number without emptying the monk under the cursor.
            local spent = fx.spendChi()
            fx.damage(fx.target, { amount = fx.amount + spent * 6 })
        end,
    },
}
