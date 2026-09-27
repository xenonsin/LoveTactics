-- BLOOD POOL: what the Gorged spills (models/gorged.lua; Wrath's vampires, reviewed 2026-09-26/27). Every blow that
-- wounds it leaves one on a tile beside it, and at half health it bursts and floods every tile around it.
--
-- TWO READINGS OF ONE PUDDLE. A vampire that steps in drinks it dry -- its Thirst resets and it heals -- and the
-- pool is gone. A living body that steps in Bleeds, and the wound is the Gorged's own (`status_bleed` with the
-- spiller as its opener), so every tile that body walks afterwards is a drink for the thing that spilled it. The
-- dead and the bloodless walk through it untouched. It lasts three turns and never stacks on one tile.
--
-- Hostile to the living, so their planners walk round it; WELCOMED by a vampire, so the brood's walk toward it.
return {
    name = "Blood Pool",
    description = "A vampire that steps in drinks it dry and heals. A living body that steps in Bleeds.",
    tags = { "blood" },
    fx = { color = { 0.55, 0.04, 0.08 } },
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN
    disposition = "hostile",
    welcomes = function(unit)
        return unit ~= nil and require("models.thirst").isVampire(unit)
    end,
    onEnter = function(ctx)
        require("models.gorged").enter(ctx.combat, ctx.hazard, ctx.unit)
    end,
}
