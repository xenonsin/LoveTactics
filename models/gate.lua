-- THE GATE: the town at the mouth of the descent, and the half of the loop that is not a floor.
--
-- Wizardry's castle is not decoration on its dungeon, it is the other side of it: an expedition ends by
-- walking back to the stair, and what makes that walk worth making is that there is somewhere to spend
-- what you carried out and somewhere to put down what you carried out on a stretcher. Without it the
-- descent was a single push with no reason to ever stop pushing, which is what the extraction prompt
-- kept failing to be (see models/descent.lua's Descent.account on why that button was hollow).
--
-- WHAT IT HAS IS NO LONGER A COUNTER. Coming up the stair IS the treatment: the surface sets every bone
-- the dive broke -- no longer: the Ward sets them now (models/injury.lua), and what this
-- screen's enter and from the city's). So a company that walks out of a floor at half strength is whole
-- the moment it is standing in a town, and the only thing that follows it up is the count.
--
-- THREE THINGS WERE PROSE OR A TOLL AND ARE NEITHER NOW, which is worth recording because each read for
-- a long time as something the game had:
--
--   the inn      injuries, as a BED: you left a body here, paid per injury at the door, and they mended a
--                injury a day while they were out of the company. It is gone, building and all, and
--                models/injury.lua's header holds the argument -- a price on recovery only ever lands on
--                the player who needed to recover, and a wipe injuries the whole expedition by
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
-- IT USED TO BE THREE CALLS AND IS ONE. A night spent the day, mended an injury off everybody lying in an
-- Inn bed, and walked out whoever that finished. The Inn is gone (see the header) and with it the only
-- reason a night had to touch the injury ledger at all -- a dive's injuries end when the company reaches
-- the surface, not when it sleeps -- so what is left is the day itself.
--
-- KEPT AS A NAMED BEAT rather than folded back into its one caller, because "a night passes" is a fact
-- about the loop and more than one thing will want to hear it.
--
-- IT NO LONGER SPENDS A DAY, because there are no days. The calendar is deleted: what a night advanced
-- was a counter whose only readers were the pool gate (which reads depth now) and the market's rotation
-- (which reads trips). Its one caller is Gate.homecoming, on the same beat that advances the counted
-- trips Player.tripsHome reads -- one event, one place.
function Gate.night(player)
    if not player then return end
    -- ...AND THE CATHEDRAL SERVES ITS TERMS, both of them, on this one beat.
    --
    -- A rest is priced in DESCENTS rather than in calendar days (models/injury.lua's ward block argues
    -- why: the calendar is nearly inert in a mode that reads its danger off the floor ladder), and a
    -- counted trip coming home is the one moment a descent is finished with -- so this is where a stay
    -- ticks (Gate.homecoming).
    --
    -- A RITE TICKS ON THE SAME EVENT, and that is not a convenience, it is the design: the city's two
    -- free paths cost the same span of the same clock, so a player learns the unit once and both prices
    -- read as the same kind of thing (models/curse.lua). A body laid up and a piece left on the altar
    -- both come back on the second homecoming, and both are paid in going down without them.
    --
    -- The rite's returns are dropped rather than merged into this function's: a hexed sword coming back
    -- clean lands in the stash and is found there, where the WARD's return is a name the stair screen
    -- puts on a line. Returns who walked out of the ward, for a caller that wants to say so.
    require("models.curse").tickRites(player)
    return require("models.injury").tickRest(player)
end

-- ---------------------------------------------------------------------------
-- A trip that counts (2026-10-23)
-- ---------------------------------------------------------------------------

-- A FIGHT WON ON THIS RUN: wandering, seated, an elite, a stair or an errand, played or walked off.
-- The one thing besides a wipe that makes a homecoming a trip (Gate.homecoming).
function Gate.markWon(run)
    if not run then return end
    run.fightsWon = (run.fightsWon or 0) + 1
end

-- Does this run count as a trip if it ended now?
function Gate.tripCounts(run, wiped)
    if wiped then return true end
    return run ~= nil and (run.fightsWon or 0) > 0
end

-- THE COMPANY IS HOME. Called by every way a descent ends (climbing out, a wipe, the Crown). A trip
-- that won a fight or ended in a wipe COUNTS: `player.tripsCounted` advances -- the clock the city's
-- schedule reads through Player.tripsHome -- and a night passes (Gate.night: the Ward's rest and the
-- altar's rite tick). An empty dip -- walk in, climb straight out -- counts for nothing, so it can no
-- longer be used to grow the city, mend a body or refill the purse.
--
-- The night used to pass at the TOP of a descent (states/game.lua's game.enter). It passes here now,
-- at the bottom of a counted one, so a rest still costs the same number of trips sat out.
--
-- Once per run: a second call on the same run is a no-op, so two exits that both reach this cannot
-- count one trip twice. Returns true when the trip counted.
function Gate.homecoming(player, run, wiped)
    if not player then return false end
    if run and run.homecomingDone then return false end
    if run then run.homecomingDone = true end
    if not Gate.tripCounts(run, wiped) then return false end
    player.tripsCounted = (player.tripsCounted or 0) + 1
    Gate.night(player)
    return true
end

-- THE OPENING PURSE (Descent.OPENING_GOLD) is topped up once per counted trip, and on the very first
-- descent. True when a fresh descent opened now is owed it. `Gate.payPurse` marks it paid.
function Gate.purseOwed(player)
    if not player then return false end
    return player.purseTrip == nil or (player.tripsCounted or 0) > player.purseTrip
end

function Gate.payPurse(player, amount)
    if not player then return end
    if Gate.purseOwed(player) then
        player.gold = math.max(player.gold or 0, amount or 0)
        player.purseTrip = player.tripsCounted or 0
    end
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
