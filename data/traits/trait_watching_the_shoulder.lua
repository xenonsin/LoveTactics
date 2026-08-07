-- Watching the Shoulder: the standing rule of Reading the Blade
-- (data/items/utility/utility_reading_the_blade.lua). Every point of Tempo held is a point of damage on
-- the duellist's blows -- the read paying out while it lasts, one for one.
--
-- WHY THE CHARM NEEDED ONE. Its own header said it plainly and did not hear itself: *"It declares the
-- pool and nothing else; Coup Droit spends it."* A 380g charm whose entire content was a pool a second
-- purchase had to arrive to drain. docs/classes.md forbids exactly that shape and then only checked the
-- spender's side of it (tests/charge_spec.lua), so the three spenders were made self-sufficient and the
-- three bankers were left as each other's back half.
--
-- ONE FOR ONE, uncapped by anything but the pool (5, or 5 with the Main-Gauche's parries feeding it
-- too). Full-pool is +5 damage on every blow, which is a weapon tier -- and it is meant to be, because
-- of what it costs to hold: the pool empties the moment you strike anyone else (`resetOn =
-- "targetSwitch"`). The Duelist is buying a bonus that a single opportunistic swing at a passing enemy
-- forfeits entirely. Nothing else on the shelf asks the player to hold their attention that still.
--
-- THE TENSION WITH COUP DROIT is the point rather than a redundancy. The spender consumes the whole
-- pool for one large blow; this pays a smaller one on every blow for as long as you keep the duel.
-- Cash in or keep reading -- and now both halves of that question exist whichever item you bought first.
--
-- A LIVE PASSIVE (Trait.liveBonus -> Combat.flatStat), because the pool it reads can vanish between one
-- stat read and the next; see trait_formation_fighter for why nothing here may bank. chargePool is a
-- pure read, so this is safe on the preview and tooltip paths that call flatStat every frame.
return {
    name = "Watching the Shoulder",
    description = "Strikes harder for each point of Tempo held.",
    live = function(ctx)
        local n = require("models.combat").chargePool(ctx.unit, "tempo")
        if n == 0 then return nil end
        return { damage = n }
    end,
}
