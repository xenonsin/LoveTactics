-- CURSE: the ground a cursed thing died on, and the ground the thing that killed it walks over.
--
-- It does two things to whatever stands in it, and it does them as one status (data/status/status_cursed.lua):
-- the body loses health it cannot get back, and nothing in the game will heal it while it stands there --
-- no spell, no potion, no Regeneration tick, no lifesteal, no Sanctified Presence. Combat.applyHeal
-- refuses at the top, which is the single funnel every heal runs through.
--
-- BOTH HALVES END WHEN YOU STEP OFF. The status declares no `lingers`, so per models/hazard.lua's rule 1
-- it is ZONE-BOUND: stamped with this zone's id, ended by Hazard.reap the instant a live curse tile is
-- no longer under the body. There is nothing to cleanse and nothing to wait out -- only ground to not be
-- standing on. That is the whole counterplay and it is deliberately a positional one, because the fight
-- this comes out of (data/characters/character_the_unseeing.lua) is about where the board has gone.
--
-- IT DEALS DAMAGE, AND THIS FILE ARGUED THE OPPOSITE FOR A WHILE. The first cut was a zone that only
-- refused healing -- "the only hazard in the game that deals no damage at all" -- on the reasoning that
-- the fight is a strangle rather than a race. Played, that made ground you could afford to ignore: a
-- board slowly filling with tiles that cost nothing to stand on is a board nobody moves off, and the
-- strangle only ever tightened on a party that was already trying to heal. The damage is what makes the
-- refusal bite, because it is what creates something to heal in the first place.
--
-- `disposition = "hostile"` earns its keep twice. It is what makes the enemy AI step AROUND this, which
-- means the curse the Unseeing's own children leave behind is ground their charges have to route past:
-- the board he is making narrows the lanes he is making. Nothing had to be written for that; the avoid
-- rule and the corpse rule simply meet.
--
-- Long-lived on purpose (25 ticks, ~5 turns). A curse that faded on the timescale a fire does would let
-- the player simply wait, and waiting is the one answer this fight must not have.
return {
    name = "Curse",
    description = "Eats at whatever stands in it, and nothing standing in it can be healed.",
    tags = { "dark" },
    duration = 25,
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_cursed")
    end,
}
