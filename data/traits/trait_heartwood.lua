-- Heartwood: the Hamadryad walks onto the board with her tree, and her life stays in it.
--
-- At the bell a Heartwood Tree is planted on a free tile beside her (character_heartwood_tree, an
-- object: it takes no turns and it can be cut down), and she is bound to it -- Heartbound, which keeps
-- her on her feet through any blow while it stands and sends her back beside it when a blow floors her
-- (data/status/status_heartbound.lua). So the fight's first question is not how to kill her. It is how
-- to reach a tree she keeps running back to, with her nymphs and her briars in the way.
--
-- The tree is a summon of hers (noClaim), and a tree she planted has no reason to outlive her -- but
-- while it stands she cannot die, so the order is fixed: tree first, then the dryad.
--
-- PLANTED AS A REAL BODY (`summoned = false`, the objective pass, 2026-10-21). The Churchyard Yew is won by
-- breaking the tree, and a conjured body never counts as standing for a kill objective (Combat.enemyStanding)
-- -- so as a summon the fight would have read as won at the bell. It is still hers (`summoner` is kept).
return {
    name = "Heartwood",
    description = "Starts each battle with her tree planted beside her; she cannot die while it stands.",
    onCombatStart = function(ctx)
        local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
        if not x then return end
        local tree = ctx.summon("character_heartwood_tree", x, y,
            { noClaim = true, control = "none", timeless = true, summoned = false })
        if tree and tree.alive then
            ctx.applyStatus(ctx.unit, "status_heartbound", { applier = tree })
        end
    end,
}
