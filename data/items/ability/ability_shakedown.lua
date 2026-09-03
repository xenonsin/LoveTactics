-- Shakedown: the Thief discipline's marquee blow, and the exact INVERSE of the Assassin's.
--
-- IT USED TO BE A SECOND PICKPOCKET -- the same theft at a higher price, with a swing and a coin
-- bolted on -- which is the one thing a shelf's deep cut cannot be. So the theft is gone entirely and
-- the strike is the item now: a beating that pays out in proportion to how much the body being beaten
-- STILL HAS. Against an untouched foe it puts its whole magnitude through a second time. Wear the same
-- foe down and it gives less every swing, until at death's door it is a plain, unremarkable jab.
--
-- THE TWO ROGUE DISCIPLINES NOW READ OFF OPPOSITE ENDS OF ONE BAR, which is the whole reason to author
-- it this way round. Coup de Grace (data/items/ability/ability_coup_de_grace.lua) is the Assassin's:
-- worthless on a fresh target, lethal on a broken one. This is the Thief's: at its best on the body
-- nobody has touched yet, worthless on the one everybody has. A rogue's turn-one and a rogue's
-- turn-five are different abilities, and the player picks a discipline by picking which end of the
-- fight they want to be paid for.
--
-- WHY THAT IS THE GREED READING and not a random curve. A shakedown extracts from someone who still
-- has something to lose; you cannot lean on a man who is already ruined. So the coin falls out on the
-- same scale as the damage -- a full purse rattles, an empty one does not -- and both halves are the
-- one sentence the Undercroft actually believes: a body is worth exactly what has not been taken off
-- it yet.
--
-- It also cuts ACROSS the shelf's own habit, deliberately. Everything else the rogue owns wants a
-- target the party has already opened -- Exploit Weakness, the Cutpurse's Tally, the whole debuff-count
-- family, and the baseline enemy posture of pressing the wounded. This is the one tool that says open
-- with me, on the thing at the back that is still untouched.
local Curve = require("models.curve")

return {
    name = "Shakedown",
    description = "Increase damage by 1% per 1% of the target's remaining health. Gain gold on the same scale.",
    flavor = "You cannot shake down a ruined man. The Undercroft's whole art is getting there first.",
    sprite = "assets/items/ability_shakedown.png",
    type = "ability",
    tags = { "guile", "physical" }, -- `guile`, the rogue's own word for a conditional multiplier
    class = "thief", -- deeper cut of the shelf: buyable only once the thief gate is cleared
    price = 575,
    unlockQuests = 6,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(12, 24), -- the floor: what it lands for against a foe with nothing left
        description = "Puts up to its own damage through a second time, in proportion to the target's remaining health.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- The multiplier, and the item's whole identity: the share of the target's health still
            -- standing. 1.0 on an untouched body, 0 on one about to fall. Read straight off the
            -- target the way the execute family reads it (Coup de Grace, Throatcut) -- same two lines,
            -- opposite direction.
            local hp = t.char and t.char.stats and t.char.stats.health
            local frac = (hp and hp.max > 0) and (hp.current / hp.max) or 1

            -- Up to the swing again on top of the swing. Authored as a share of `fx.amount` rather
            -- than a second number so the forge only has to climb one curve, and the tooltip's damage
            -- row stays the single figure a player doubles in their head.
            fx.damage(t, { amount = fx.amount + math.floor(fx.amount * frac) })

            -- And what falls out of the pocket while they are being held: the same scale, a smaller
            -- number. Deliberately modest -- A Price on the Head is the shelf's money ability and this
            -- is not competing with it -- but present, because an extortion that pays nothing is just
            -- a punch and the item is not named for a punch.
            fx.bounty(math.floor((10 + fx.level) * frac))
        end,
    },
}
