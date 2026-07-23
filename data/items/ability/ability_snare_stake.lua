-- The Snare Stake: an iron peg and a loop of wire, driven into a seam of the floor. It draws no blood.
-- The first enemy across it simply stops being able to leave (data/traps/snare_stake.lua).
--
-- THE PURE HOLD, sold with the damage deliberately removed. The Lodge already stocks a spike trap
-- (damage, no hold), a snare (a short hold), and a bear trap (both, expensively). This is the root on
-- its own, at twice the duration and half the price -- and the reason a trapper wants that trade is
-- subtle and specific: a wounded target might be finished by somebody else, and then the ground was
-- wasted. A HELD target is still there when the volley arrives.
--
-- HIDDEN, which is what separates it from the knight's Grasping Hollow. The hollow is visible terrain
-- and the enemy AI paths around it, so it denies ground. This is a lie about safe ground: the AI walks
-- into it because it does not know, and finds out standing still. Same effect, opposite counterplay --
-- one is a wall you can see, and one is a floor you trusted.
--
-- ADJACENCY: a `bow` beside it, like everything else on this shelf that matters. A stake with no bow
-- next to it holds a foe in place for a party that has nothing to do about it, which is a turn spent
-- being tidy. The gate is the item saying out loud what it is for.
--
-- The forge raises the HOLD rather than any damage, because a hold has exactly one axis to grow along
-- -- the same reasoning a barrier's upgrade buys coverage rather than a bigger number.
return {
    name = "The Snare Stake",
    description = "Sets a hidden stake: roots the first enemy across it, and draws no blood.",
    flavor = "The Lodge's oldest tool, and the only one it never improved. There was nothing to improve.",
    sprite = "assets/items/ability_snare_stake.png",
    type = "ability",
    tags = { "physical" },
    class = "hunter",
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 3,
        cost = { stat = "stamina", amount = 7 },
        support = true, -- placing a thing; it lands nothing on the turn it is set
        requiresAdjacent = { tag = "bow" },
        effect = function(fx)
            -- The trap's `amount` rides in as the root's DURATION rather than as damage (see the trap's
            -- own onTrigger). Base ~2 turns, and a turn more for every few levels of forging.
            fx.placeTrap(fx.tx, fx.ty, "snare_stake", { amount = 10 + 2 * fx.level })
        end,
    },
}
