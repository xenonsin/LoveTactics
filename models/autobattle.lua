-- Autobattle: run a whole fight against the model with nobody watching.
--
-- models/combat.lua is headless by construction and models/ai.lua is pure, so a battle has always been
-- resolvable without a board -- states/duel_debug.lua already drives one that way. What was missing was
-- a loop that does it the way states/battle.lua does it, which is what makes the answer trustworthy:
-- the same plan, the same walk-then-act order, the same free-action handling. A simulation that
-- resolved turns slightly differently from the real thing would bill the player for a fight they never
-- could have had.
--
-- Used by the walk-off path (states/game.lua): a fight the company has outgrown is resolved here, and
-- what it SPENDS is real. Party characters ride in by reference exactly as they do in a live battle, so
-- health and mana come off the roster, consumable stacks decrement, technique banks, purse gold is
-- spent and a theft lands in the stash -- all through the ordinary code paths, because they ARE the
-- ordinary code paths. That is the billing, and it is not modelled or approximated anywhere.
--
-- What this deliberately CANNOT finish is any fight whose win clock lives in the battle state rather
-- than the model -- reinforcement waves, a `defend`/`reach`/`survive` objective. Those are refused
-- upstream by EncounterBattle.eligible; this loop's turn guard is the backstop, not the gate.
--
-- Pure (no love.graphics), so it loads under the headless tests.

local Combat = require("models.combat")

local Autobattle = {}

-- The turn ceiling. Two evenly matched sides that cannot reach each other would otherwise spin
-- forever; so would a fight whose objective the model has no way to satisfy. High enough that no
-- real side-fight comes near it -- an ordinary trail fight is decided inside forty -- and low enough
-- that tripping it is instant rather than a hang.
Autobattle.MAX_TURNS = 500

-- One unit's whole turn, resolved in the same order states/battle.lua resolves an AI turn in
-- (executeEnemyAction -> resolvePlanAction): plan, walk, act, and pass if the action did not happen,
-- so a turn can never soft-lock on a unit that did nothing.
local function takeTurn(combat, unit)
    -- A body nobody drives (a charmed-off construct, a scripted prop) simply hands the turn on.
    if unit.control == "none" then
        Combat.pass(combat, unit)
        return
    end

    local plan = Combat.planEnemyAction(combat, unit)
    if not plan then
        Combat.pass(combat, unit)
        return
    end

    -- The plan aims from the tile the unit walks to, so the walk resolves first.
    if plan.move then
        -- Around the fire rather than through it, where there is fire and a way around it inside the
        -- budget: Combat.hazardRoute answers nil otherwise, and planMoveVia re-checks the detour it
        -- does hand back. The same two lines states/battle.lua's enemy turn takes, so a headless run
        -- and a watched one walk the same feet.
        local cells = Combat.hazardRoute(combat, unit, plan.move.x, plan.move.y)
        local route = (cells and Combat.planMoveVia(combat, unit, cells))
            or Combat.planMove(combat, unit, plan.move.x, plan.move.y)
        if route then Combat.runMove(combat, route) end
    end
    -- Cut down on the approach (a trap, an overwatch shot): the turn is over with them, and passing
    -- for a corpse would be a second turn nobody took.
    if not unit.alive then return end

    local acted = false
    if plan.item then
        if plan.strike then
            -- Aimed at a board object (a wall, a keg) rather than a body. A different call, and using
            -- the wrong one silently misses -- see states/battle.lua's resolvePlanAction.
            acted = Combat.strikeObject(combat, unit, plan.item, plan.tx, plan.ty) and true or false
        else
            acted = Combat.useItem(combat, unit, plan.item, plan.tx, plan.ty,
                plan.windup, nil, plan.spend) and true or false
        end
    end

    if not acted and unit.alive then Combat.pass(combat, unit) end
end

-- THE LAST STAND IS GONE WITH THE MOVE THAT MADE IT. A party whose field was empty but whose bench
-- was not had NOT lost, so a loop that only evaluated would spin until the guard tripped -- and this
-- walked the next body in, which is what a player would have done.
--
-- Combat.eliminated no longer reads the bench (there is no way back onto the board), so an empty
-- field IS a loss and the loop resolves on its own.

-- Run `combat` to a decision. Returns `result, turns`:
--   "win" | "loss" -- what Combat.evaluate settled on
--   nil            -- the guard tripped; the fight is UNDECIDED, not a draw
--
-- The combat must already be open (Combat.openBattle). Both sides are driven by the AI, the party
-- included -- this is exactly `autoPilot` in the battle state, with the drawing taken out.
function Autobattle.run(combat, opts)
    opts = opts or {}
    local maxTurns = opts.maxTurns or Autobattle.MAX_TURNS

    local turns = 0
    local result = Combat.evaluate(combat)
    while result == nil do
        if turns >= maxTurns then return nil, turns end
        turns = turns + 1


        -- A FREE action (or a surged extra one) leaves combat.turn OPEN on the same unit rather than
        -- ending it. Resume that turn rather than opening a new one: Combat.startTurn clears
        -- `freeActionsUsed` and `actionSpent` at turn start, so re-opening here would hand the unit a
        -- fresh budget of free actions every pass and the loop would never leave it.
        local unit = combat.turn and combat.turn.unit
        if not (unit and unit.alive) then unit = Combat.startTurn(combat) end
        if not unit then break end -- nobody left standing on either side

        takeTurn(combat, unit)
        -- The cue queue self-bounds, but draining keeps a long fight's memory flat and matches what a
        -- watched battle does at the end of every turn.
        Combat.drainFx(combat)

        result = Combat.evaluate(combat)
    end

    return result, turns
end

return Autobattle
