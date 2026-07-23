-- Slipstep: the Undercroft's answer to being attacked at all, and the only reflex in the game that
-- does not answer along the line the blow came down. Struck from anywhere -- a blade in the ribs, an
-- arrow from across the field, a bolt out of a tower -- the knife is simply gone from where it was hit
-- and standing beside whoever threw it, with the cut already made.
--
-- What it is FOR is stated by what every other counter in this file cannot do: reach. The whole reflex
-- economy is built on "can the bearer reach back at the tile the blow came from" (Trait.mayCounter), so
-- a knife -- reach one, the shortest band in the game -- answers almost nothing. This one refuses the
-- question rather than winning it. It declares `closes`, and a closing reflex has no band at all:
-- distance stops mattering and the LANDING starts. It needs open ground beside its attacker to arrive
-- on, and that is the fact the player reads off the board instead of a range.
--
-- Which is also the counterplay, and it is a positional one rather than a timer: fight it from inside
-- a press, with every tile around you occupied, and the knife has nowhere to appear. An archer that
-- keeps a bodyguard on each side of it is answering this reflex correctly.
--
-- Priced like every answer (Trait.answerCost): a swing costs what a swing costs, doubled for each
-- answer already thrown this round. Priced at ONE TILE, because that is where the swing is actually
-- thrown from -- the knife is billed as a knife however far away the shot came from, which is exactly
-- the discount the closing buys and the reason the blade that carries it is a rank-4 item.
--
-- Two things it deliberately is not:
--   * NOT a negation. Unlike Riposte (data/traits/trait_riposte.lua) the blow lands in full -- this
--     fires from the ordinary onDamaged hook, so it only ever answers a hit the bearer SURVIVED, and a
--     killing blow goes unanswered. It buys position and a cut, never safety.
--   * NOT free movement. The bearer really does end up over there, in the open, next to something that
--     just attacked it. Half the time the reflex is the thing that gets its bearer killed, and that is
--     the trade an assassin's blade is supposed to offer.
--
-- It answers a REACTION too (`answersReactions`), unlike Parry: a knife that vanishes has nothing to
-- volley with -- there is no guard being traded back and forth, only a body arriving somewhere new --
-- and a rogue that cannot answer the counter to its own strike is a rogue that never gets to use this.
return {
    name = "Slipstep",
    description = "When struck from any range, appear beside the attacker for a swing's stamina and cut.",
    counter = {
        closes = true,          -- it goes to them; reach gates nothing (see Trait.mayCounter)
        answersReactions = true,
    },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        -- Where it arrives. mayCounter already refused a hemmed-in attacker, so this normally hands
        -- back a tile -- but it is asked again here rather than trusted, since a reflex thrown after
        -- another one may find the board moved under it.
        local x, y = ctx.openTileNear(ctx.attacker.x, ctx.attacker.y)
        if not x then return end
        -- Cost last, after every free refusal above: a rogue with an empty pool stays where it is and
        -- is billed nothing for the step it did not take.
        if not ctx.pay() then return end
        ctx.log("action", string.format("%s slips behind %s!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"))
        -- The arrival springs whatever is on the tile (a trap, a fire) exactly as a walk would -- the
        -- knife crosses no ground to get there, but it does have to stand somewhere when it lands.
        ctx.teleport(x, y)
        ctx.basicAttack(ctx.attacker)
    end,
}
