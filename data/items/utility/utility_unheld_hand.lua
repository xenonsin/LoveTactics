-- Sunho's bound relic (Monk). He carries nothing and needs less, and this is the pool rather than
-- another way to spend it.
--
-- IT IS THE ENGINE, NOT A SPENDER, and that correction is the design. An earlier draft was a line
-- strike that ignored defense -- which is Asura Strike, already on the Monk shelf, with a bigger
-- number. A relic that replaces the shelf's best cast is a purchase you stop making. This refills the
-- CHI those casts run on (Combat.chi, banked by bare-handed blows and nothing else), so Flurry and
-- Asura Strike are what the relic is bought for rather than what it competes with.
--
-- THE GATE IS FIVE BARE-HANDED BLOWS, which is the same tally chi itself banks from -- so charging the
-- relic and charging the pool are one activity, and the four fist charms (Iron, Swift, Shadow, Drunken)
-- are the build in both directions.
--
-- FAITHFUL APPROXIMATION, said out loud rather than implied: the design also had the next fist ability
-- cost nothing, and the engine has no free-cast primitive to hang that on. The refill is the whole of
-- what ships. Chi is DERIVED (banked tallies less what has been spent), so refilling means clearing the
-- spend rather than adding to a store -- the copy below is why other pools are not clobbered with it.
return {
    name = "The Unheld Hand",
    description = "Refills your chi to everything your fists have earned this fight.",
    flavor = "The hand that holds nothing is the one with something left in it.",
    sprite = "assets/items/sig_unheld_hand.png",
    type = "utility",
    tags = { "signature", "physical" },
    class = "priest",
    discipline = "monk",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        description = "Clears every point of chi you have spent this fight.",
        unlock = { event = "unarmedHit", count = 5, text = "Land 5 unarmed blows" },
        effect = function(fx)
            -- Copied rather than replaced: fx.bank writes a whole value onto the unit, and banking a
            -- bare { chi = 0 } would quietly wipe every other charge pool the body is holding.
            local spent = fx.user.chargeSpent or {}
            local cleared = {}
            for key, value in pairs(spent) do cleared[key] = value end
            cleared.chi = 0
            fx.bank("chargeSpent", cleared)
        end,
    },
    -- chi back for everything the fists earned
    bonus = { magicDamage = 1 },
}
