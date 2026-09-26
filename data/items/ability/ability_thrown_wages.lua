local Curve = require("models.curve")

-- THROWN WAGES: the Paymaster's trophy, and his Pay Out turned round (data/characters/character_the_paymaster.lua).
-- Settled in round 5 of "The Paymaster" (2026-09-26): "Use company gold to toss at a tile to create a gold
-- heap or deal damage."
--
-- ONE CAST, TWO ANSWERS, AND THE TILE PICKS WHICH. Aimed at open ground, the gold lands as a coin heap worth
-- what was thrown (hazard_coin_heap) -- bait the dwarves will walk to and sicken on, or a purse the company
-- banks again by walking over it on the way past. Aimed at a foe, the same fistful is thrown AT them: the
-- floor of the blow plus a point for every 5 gold, which is Blood Money's rate (ability_blood_money.lua).
--
-- THE COMPANY'S OWN GOLD, spent live through the purse seam (fx.spendPurse -> Combat.spendPurse): real
-- coin, gone when it is thrown, clamped to what is on hand, and inert in both previews. TOSS is one heap's
-- worth twice over -- the floor's own heap is 10 (hazard_coin_heap's HEAP_GOLD) -- so a thrown heap is a
-- fat one, and the blow reaches four points past its floor. With an empty purse the throw still lands, and
-- it is only the blow's floor: there is nothing to make a heap of.
--
-- Mammonite, the purse's own shelf -- and an unstocked trophy: seen on the rack, sold nowhere
-- (tests/discovery_spec.lua's TROPHIES).
local TOSS = 20 -- gold per throw
local PER_POINT = 5 -- Blood Money's rate: one point of the blow for every 5 gold

return {
    name = "Thrown Wages",
    description = "Throw 20 gold at a tile: a coin heap on open ground, or damage to a foe, 1 more per 5 gold.",
    flavor = "It spends the same either way. The only question is whether somebody catches it with their face.",
    sprite = "assets/items/ability_thrown_wages.png",
    type = "ability",
    tags = { "physical", "impact", "guile" }, -- guile: the purse shelf's word, as on Blood Money
    class = "mammonite",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        speed = 4,
        cost = { stat = "stamina", amount = 4 }, -- the arm; the purse is the true cost
        damage = Curve.ramp(8, 18), -- fx.amount: the blow's floor, before a coin is counted
        description = "Consume up to 20 gold. Open ground: a coin heap of that gold. A foe: damage, 1 more per 5 gold.",
        effect = function(fx)
            local x, y = fx.tx, fx.ty
            local there = fx.unitAt(x, y)
            if there and fx.user and there.side == fx.user.side then return end -- never at your own
            local paid = fx.spendPurse(TOSS)
            if there then
                fx.damage(there, { amount = fx.amount + math.floor(paid / PER_POINT) })
            elseif paid > 0 then
                fx.placeHazard(x, y, "hazard_coin_heap", { amount = paid })
            end
        end,
    },
}
