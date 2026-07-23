-- A greatsword, so it winds up (docs/weapons.md). Its extra is that the wind-up cannot be taken away:
-- `steadfast` on the ability makes Combat.interruptChannel refuse outright, so a Stun, a Freeze or a
-- Silence lands on the bearer in full and the blade comes down anyway.
--
-- Quest-only: `class` with no `price`.
--
-- This is the answer to the one question every greatsword has to answer, and every other one in the game
-- answers it by dodging: the wind-up is a turn during which the enemy gets to act, and the correct enemy
-- play has always been to break it. Headsman's Cleaver shortens the window. Avalanche accepts a longer
-- one for width. Kingsfall simply stops the counterplay from existing -- which is why it is a thing you
-- are given rather than a thing on a shelf.
--
-- What it deliberately does NOT do is refuse the control. The bearer is stunned; the bearer is shoved
-- down the turn order; the bearer's next turn comes correspondingly late. All that is declined is the
-- CANCELLATION. A hammer swung at a Kingsfall is not a wasted turn, it is an insufficient one -- and
-- keeping that line is what stops this being an answer to hard control generally rather than to the one
-- interaction it was forged for.
return {
    name = "Kingsfall",
    description = "Winds up, then falls on one tile. Nothing breaks the wind-up -- not a stun, not ice, not silence.",
    flavor = "They hit him with everything they had, in the correct order, at the correct moment. Then the sword arrived.",
    sprite = "assets/items/kingsfall.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        channel = 2,
        -- The extra, in one word. See Combat.interruptChannel: the flag lives on the ABILITY rather than
        -- on the unit, so a fighter is unbreakable only while swinging this and inherits nothing.
        steadfast = true,
        cost = { stat = "stamina", amount = 16 },
        -- Under the iron greatsword's. Certainty is what it sells, and certainty is worth more than the
        -- four points of Power it gives up for it.
        damage = { 20, 22, 24, 27, 29, 31, 33, 36, 38, 40, 43 },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
        end,
    },
}
