-- Fen's bound relic (Skirmisher). She is never where the last swing was.
--
-- IT BANKS `tilesMoved` -- ground crossed on her own feet, filled at Combat.moveUnit and measured in
-- TILES rather than move cost, so rough terrain does not quietly fill it faster. Twelve tiles is about
-- three turns of actually skirmishing, which is the point: a skirmisher who stood still has not been
-- one, and the relic is unavailable to her precisely then.
--
-- BEING SHOVED DOES NOT COUNT. Forced movement pays no move cost and does not pass through the walk,
-- so a relic that filled on knockback would reward standing in front of a mace -- the opposite
-- instinct. Enforced at the seam rather than here, which is why the same rule holds for every future
-- item that reads this tally.
--
-- WHAT IT BUYS is the thing the shelf keeps almost giving her: Running Shot already scales with tiles
-- crossed, Skirmisher's Momentum already pays for having moved, and the Harrier's Bow already refuses
-- to close her movement. This stops her choosing between going and hitting for the rest of the fight.
return {
    name = "Ground Given",
    description = "Strike, take your whole movement, and strike again.",
    flavor = "Ground given is not ground lost. It is the shape of the next place she will be.",
    sprite = "assets/items/sig_ground_given.png",
    type = "utility",
    tags = { "signature", "physical" },
    class = "hunter",
    discipline = "skirmisher",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        description = "A blow, then your movement returns and the turn does not end.",
        unlock = { event = "tilesMoved", count = 12, text = "Cross 12 tiles" },
        counter = function(unit)
            return unit and require("models.combat").tallyCount(unit, "tilesMoved") or 0
        end,
        counterLabel = "Tiles",
        effect = function(fx)
            fx.damage(fx.target)
            -- The whole point: the strike does not close the turn. A second action is the engine's
            -- own way of saying "and then keep going" (Combat.grantExtraAction), which also means the
            -- movement she has not spent is still hers to spend.
            fx.grantExtraAction(1)
        end,
    },
    -- strike, cross the board, strike again -- both halves
    bonus = { movement = 1, damage = 1 },
}
