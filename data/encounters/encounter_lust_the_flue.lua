-- THE FLUE: the Lust circle's fourth elite, and the only fight on the stratum where clearing the chaff
-- first is the right opening.
--
-- A CHIMNEY IS WHAT TURNS A HEARTH INTO A HOUSE FIRE, and a keep this size has one running the height
-- of it. What is standing in the throat of it is the two things the blooding left in this building,
-- meeting: the heat from the lamp rooms and the draught from the bell loft, which apart are a cost and
-- a nuisance and together are the thing that takes the roof off (data/characters/character_whirl_elemental.lua).
--
-- WHAT IT ASKS IS NOT WHERE YOU WILL STAND OR WHETHER YOU CAN REACH IT. The Eyrie takes the choice of
-- where to stand; the Drowned Stair prices every tile you move; the Lady Chapel takes the swing. This
-- takes the OPENING. A company's ordinary way into a fight -- walk up, hit the big one -- is the exact
-- move that arms it: Backdraught lights the front rank, and the Chimney-Draw hauls a burning body the
-- whole length of the room where a cold one only stumbles a tile. Four elites on one stratum, four
-- different things confiscated.
--
-- THE ESCORT IS THE FUEL LINE, AND THAT IS WHY IT IS THIS ESCORT AND NOT A MIXED ONE. The Drowned
-- Stair's argument holds everywhere else on this floor -- one kind of body, so the slope is legible --
-- and here the single kind is chosen for a second reason on top of the first. A Fire Elemental bills every
-- blow thrown at it (trait_wanting_costs), so each one is a source of fire the Whirl Elemental did not have to
-- light itself, and the party lights them by doing the only thing it can do about a Fire Elemental. The
-- escort is not standing beside the elite; it is loading it.
--
-- SO THE LAW OF THIS CIRCLE HAS AN EXCEPTION, AND THIS IS IT. "Cut the one doing it" has been the
-- stratum's stated answer since the re-premise and the Lady Chapel is where it finally costs something
-- to follow. Here it is WRONG: go straight at the Whirl Elemental through a room of burning lamps and every
-- step of the way you are handing it the handholds it pulls you in by. The inversion is readable off
-- the board -- the fire is visible, the haul is visible, and which bodies are on fire is the readout
-- the whole fight turns on -- which is what makes it a lesson rather than a gotcha.
--
-- AND THE WICKS DO NOT CARE THAT IT ANSWERS IN FIRE. Backdraught catches its own escort exactly as the
-- Matriarch's wing-beat catches her flock, and exactly as harmlessly here: the escort resists fire
-- almost entirely. That agreement between a body and its chaff is the only one on the stratum, and it
-- is why these two are seated together and nothing else is seated with either.
--
-- A SPARE RATHER THAN A BILLING, deliberately, on the Lady Chapel's own reasoning. Descent.SINS bills
-- this circle's two rungs to its two original animals -- the coils hold the approach and the wings hold
-- the seat, cheapest rule first -- and an argument that careful is not worth unpicking to seat a
-- fourth. It turns up at ELITE_WEIGHT on either floor instead (Descent.floorPool's elite branch keeps
-- the unnamed ones legal so a circle's spares still appear).
--
-- Locked to the castle stratum by ctx.biome, the same gate every circle uses.
local Band = require("models.band")

return {
    name = "The Flue",
    kind = "elite",
    weight = 1, -- rarest thing on the floor: the body a stratum is remembered for
    condition = function(ctx) return ctx.biome == "castle" end,
    -- RUNG 1, beside the Drowned Stair. Lightest of the castle's four measured, and the one castle
    -- fight where the stratum's standing counterplay REVERSES -- clear the chaff first, because the
    -- fire is what the wind pulls on. A lesson that inverts a rule belongs on the floor that floor
    -- is walked onto first. One elite, one floor: see models/encounter.lua's eligibility note.
    rung = 1,
    composition = function(ctx)
        local list = { "character_whirl_elemental" }
        return Band.fill(list, ctx, "character_fire_elemental", { base = 2, per = 5 })
    end,
}
