-- THE GATE: the town at the mouth of the descent, and the half of the loop that is not a floor.
--
-- Wizardry's castle is not decoration on its dungeon, it is the other side of it: an expedition ends by
-- walking back to the stair, and what makes that walk worth making is that there is somewhere to spend
-- what you carried out and somewhere to put down what you carried out on a stretcher. Without it the
-- descent was a single push with no reason to ever stop pushing, which is what the extraction prompt
-- kept failing to be (see models/descent.lua's Descent.account on why that button was hollow).
--
-- WHAT IT HAS IS NO LONGER A COUNTER. Coming up the stair IS the treatment: the surface sets every bone
-- the dive broke, free and without being asked (models/wound.lua's Wound.clear, called from this
-- screen's enter and from the city's). So a company that walks out of a floor at half strength is whole
-- the moment it is standing in a town, and the only thing that follows it up is the count.
--
-- THREE THINGS WERE PROSE OR A TOLL AND ARE NEITHER NOW, which is worth recording because each read for
-- a long time as something the game had:
--
--   the inn      wounds, as a BED: you left a body here, paid per wound at the door, and they mended a
--                wound a day while they were out of the company. It is gone, building and all, and
--                models/wound.lua's header holds the argument -- a price on recovery only ever lands on
--                the player who needed to recover, and a wipe wounds the whole expedition by
--                construction, so the company that could least afford the bill was the one always
--                handed it. What paces the campaign instead is Descent.count, which cannot lock
--                anybody out.
--
--   the temple   was described here as what "turns a body in a sack back into somebody who can hold a
--                sword", carried out by a rescue stop on a later dive. Neither was ever written. A wipe
--                does not leave bodies underground -- the company wakes here and only the HAUL stays on
--                the floor (states/game.lua's onLoss). Stranding was designed in full during the
--                descent-loop pass and cut: an absent body dominates a degraded one.
--
--   the store    "draughts and a spare blade" off data/vendors/gate_store.lua. There is no store at this
--                screen; the shops are cards in the city (states/houses.lua).
--
-- PURE MODEL. No love.graphics, no state switching -- the eligibility and the beats live here so a spec
-- can drive them, and states/gate.lua is the screen over the top. Same split models/descent.lua keeps
-- against the screens that draw it.

local Gate = {}

-- ---------------------------------------------------------------------------
-- A night passing
-- ---------------------------------------------------------------------------

-- WHAT A NIGHT IS, in one place, so the one thing that causes one does not spell it out inline.
--
-- IT USED TO BE THREE CALLS AND IS ONE. A night spent the day, mended a wound off everybody lying in an
-- Inn bed, and walked out whoever that finished. The Inn is gone (see the header) and with it the only
-- reason a night had to touch the wound ledger at all -- a dive's wounds end when the company reaches
-- the surface, not when it sleeps -- so what is left is the day itself.
--
-- KEPT AS A NAMED BEAT rather than folded back into its one caller, because "a night passes" is a fact
-- about the loop and the calendar is not the only thing that will ever want to hear it. models/calendar
-- names this function as its one caller and that stays true.
function Gate.night(player)
    if not player then return end
    require("models.calendar").spend(player)
end

-- ---------------------------------------------------------------------------
-- Going back down
-- ---------------------------------------------------------------------------

-- Can this company descend at all? SOMEBODY PICKED, which with no run and no picks is the first four of
-- the roster (Descent.party), so a company that has never opened this screen still has a stair.
--
-- It used to ask only whether the roster was non-empty, which was the same question while everybody
-- walked down. The expedition is four now and chosen, so a player who has unticked the last name is
-- standing at a stair with nobody to send -- and the honest answer is that the stair does not open,
-- rather than that it opens onto an empty board.
function Gate.canDescend(player, run)
    if #((player and player.roster) or {}) == 0 then return false end
    return #require("models.descent").party(run, player) > 0
end

return Gate
