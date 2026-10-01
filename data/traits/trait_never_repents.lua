-- NEVER REPENTS, ONLY RETURNS: the Phoenix's rule, carried on its organ (data/items/utility/
-- utility_never_repents.lua; "Pride's Bestiary", 2026-09-30).
--
-- Felled, it burns down to an EMBER on its own tile (character_phoenix_ember, an object that takes no turns,
-- as the Dragon Egg and the scarab's egg are), which rises again as the Phoenix in three turns
-- (status_rekindling), at full health and +3 Damage for every time it has died (status_reborn). The Ember
-- counts on its side, so a kill-all is not won while one stands: BREAK THE EMBER to end it. The risen Phoenix
-- wears this same organ, so every death is another Ember, and every rising is angrier than the last.
--
-- On onDeath rather than in Trait.trySurvive: the Phoenix really does fall -- the turn order loses it, the
-- company sees it go -- and what is left on the tile is a different, breakable thing. A conjured copy that is
-- dismissed fires no onDeath and leaves nothing; Sundered, the organ is silent and the Phoenix stays dead.
return {
    name = "Never Repents",
    description = "Felled, it leaves an Ember that rises as the Phoenix in 3 turns, +3 Damage per death. Break it.",
    onDeath = function(ctx)
        local unit = ctx.unit
        if not unit or unit.summoned or unit.decoyOf then return end
        require("models.pride_elites").layEmber(ctx.combat, unit)
    end,
}
