-- THE TITHE: the Godling's rule (data/items/utility/utility_godlings_hunger.lua). Round 2 (2026-09-25):
-- the approved Godling's Hoard-Crust fed on coin heaps, and "Kobolds don't care about gold" took its food
-- away -- so it feeds on its worshippers instead.
--
-- A KOBOLD THAT ENDS ITS TURN BESIDE THE GODLING GIVES ITSELF UP. It is devoured whole (Combat.devour --
-- a living body on the eater's own side is its larder, which is exactly what this is), and the Godling
-- heals a tenth of its health and takes a stack of GLUT: +2 Damage, +2 Defense, no cap (status_glut).
-- The Devotees in the Nest walk in to be eaten (the `devotee` posture); any other kobold that fights
-- beside it is eaten too.
--
-- THE HOARD-THANE TURNED ROUND, which is what keeps the two elites of Greed from being one fight twice:
-- every dwarf the company kills feeds the Thane; every kobold it DOESN'T kill before it reaches the
-- Godling feeds this. The answer to both is the Bare Patch (trait_bare_patch) -- a critical strips every
-- Glut at once -- which the Thane's Mithril Shirt refuses and the Godling cannot.
local HEAL_SHARE = 0.10

return {
    name = "The Tithe",
    description = "A kobold that ends its turn beside you gives itself up: you heal and take a stack of Glut.",
    onAnyTurnEnd = function(ctx)
        local combat, god, actor = ctx.combat, ctx.unit, ctx.actor
        if not (combat and god and god.alive and actor and actor.alive) then return end
        if actor.side ~= god.side then return end
        local Devotion = require("models.devotion")
        local Combat = require("models.combat")
        if not Devotion.isDevout(actor) or Combat.unitGap(god, actor) > 1 then return end
        local name = (actor.char and actor.char.name) or "A kobold"
        if not Combat.devour(combat, god, actor) then return end
        local Status = require("models.status")
        Status.apply(combat, god, "status_glut", { magnitude = 1 })
        local hp = god.char.stats.health
        ctx.heal(god, math.max(1, math.floor((hp.max or 0) * HEAL_SHARE + 0.5)))
        ctx.log("action", string.format("%s gives itself to %s.", name,
            (god.char and god.char.name) or "the Godling"), god)
    end,
}
