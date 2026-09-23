-- THE LAMP ROOM: the Lust circle's fourth ordinary fight, and the first one on the stratum that is not
-- about where anybody is standing.
--
-- A KEEP THIS SIZE HAS A ROOM THE LIGHTS ARE KEPT AND LIT IN, and the order that held this one lit a
-- great many of them. What is standing in it now is what the blooding drove out of the bodies it took
-- (data/characters/character_fire_elemental.lua) -- heat with nothing left around it, still burning in the
-- room it was lit in, several hundred years after the last person knelt and paid for one.
--
-- IT IS THE ONE FIGHT IN THE CIRCLE A COMPANY CANNOT SOLVE BY CHOOSING ITS GROUND. The Open Roof asks
-- where you are willing to stand; the Cistern makes standing still the trap; the Long Gallery does not
-- let you pick at all. Every one of those is an argument about the board. A Fire Elemental has no opinion
-- about the board -- it charges you for HITTING it, from any distance, by any means
-- (trait_wanting_costs). So a party that has spent the floor learning to answer this stratum with
-- position walks into the one stop position does not answer.
--
-- WHAT DOES ANSWER IT IS SPEED, AND THAT IS THE LESSON. Two rules make the same point from opposite
-- ends. A reflex is held while a cast resolves and the flush skips the fallen (Combat.endAnswers), so a
-- Fire Elemental KILLED by the blow that reached it bills nobody -- commit, and the room is free. And Burn
-- refreshes rather than stacking (Status.apply), so four bodies pounding one flat in a round take one
-- burn between them rather than four. Chip at them instead, one careful exchange at a time, and the
-- company walks out of the room alight. This is the only stop on the stratum where the correct play is
-- to be reckless, and it is the cheapest rung at which to find that out.
--
-- THEY HOLD, WHICH IS WHAT MAKES IT A ROOM RATHER THAN A FIGHT. `defensive` -- a lamp room can be
-- opened when the company chooses, walked past, or left burning behind the line (AI.POSTURES). That is
-- Fire Emblem's activation rule and it is doing real work here: the one stop on this floor a party gets
-- to schedule.
--
-- CLOSING THE LAST OF A HOLE, AND SAYING SO. The 2026-09-22 cut left the castle fielding 0 ordinary
-- fights; the Open Roof, the Cistern and the Long Gallery brought back three and the note on the Open
-- Roof asked for ground that was "not a harpy". This is the fourth, and it is not an animal at all.
--
-- Locked to the castle stratum by ctx.biome, the same gate every circle uses. NO DEPTH GATE: ITS CIRCLE
-- IS ITS PLACEMENT. A circle owns a fixed stratum, so a depth on top of that is a second opinion about
-- where this goes, and it disagrees the moment the shuffle deals Lust at another depth
-- (Descent.sinOrder).
local Band = require("models.band")

return {
    name = "The Lamp Room",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "castle" end,
    rung = 2, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        -- A ROOM OF ONE KIND, on the Open Roof's own argument. What makes four Fire Elementals worse
        -- than one is not that one of them is bigger -- it is that there are four bills to pay and
        -- only one of them can be settled in a turn.
        --
        -- AND IT IS AUTHORED AT THE TIER'S CEILING, WHICH IS THE ONE CASE models/band.lua SAYS TO LEAVE
        -- ALONE. A centre of four against Arena.SKIRMISH_CAP's four means the roll lands under the clamp
        -- and the player sees the ceiling every time -- "which is the clamp telling you the stop was
        -- authored above its own tier. Where that is true and deliberate (a swarm is meant to arrive at
        -- the ceiling), leave it." This is that: the body is 22 health and the fight is the number of
        -- bills, so a lamp room with two lamps in it is not a lighter version of this stop, it is a
        -- different one. The walk-over sweep in tests/descent_spec is what says so out loud -- at the
        -- Cistern's band this rated close enough to 200% that the floor would have offered to skip it.
        local list = { "character_fire_elemental" }
        return Band.fill(list, ctx, "character_fire_elemental", { base = 3, per = 5 })
    end,
}
