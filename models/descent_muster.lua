-- THE MUSTER: the company a descent is fought with, chosen at the mouth of the run and never again.
--
-- A descent is a clean run (models/descent.lua) -- nothing is carried in and nothing is banked out -- so
-- the mode has to hand the player a company from somewhere, and the first decision of a run is which
-- bodies go down. That is what this is: a shelf of candidates, a purse, and a company built out of it.
--
--   local shelf = Muster.shelf(seed)
--   -- ... player picks; Muster.affordable / Muster.cost gate the picking
--   local company = Muster.company(picks)      -- instantiated, kits intact
--   local profile = Descent.newProfile(company)
--
-- WHAT IT SELLS IS BODIES, NOT BUILDS, and that is the one line separating this from Draft's store.
-- Draft strips a bought unit to its chassis (models/draft_chassis.lua) because there the gear row IS the
-- draft -- a run's whole build comes off the shop. A descent's gear comes off its FLOORS: the caches, the
-- fights' salvage, and the overworld's own merchant stops, all of which already exist and all of which
-- are the reason to go down another flight. Selling gear here as well would put two sources in front of
-- the same question and make the floors' answer the less interesting one. So a body arrives wearing
-- exactly what its blueprint authors, and what happens to it after that is the run's business.
--
-- Pure model -- no love.graphics, love.filesystem untouched -- so it loads under the headless runner.

local Character = require("models.character")
local Combat = require("models.combat")
local DraftRun = require("models.draft_run")
local Player = require("models.player")

local Muster = {}

-- How many bodies a descent musters. The company MARCHES eight and stands Player.MAX_FIELD of them on
-- any given board (docs/deployment.md), so eight is the full company and the deployment phase still gets
-- a real choice on every floor. The minimum is the field itself: a run that walks in with three bodies
-- is choosing to fight every floor a man down, which is a decision, but walking in unable to fill the
-- board is not.
Muster.COMPANY_MAX = 8
Muster.COMPANY_MIN = Player.MAX_FIELD

-- How many candidates the shelf offers. More than COMPANY_MAX so the muster is a choice rather than an
-- inventory -- a shelf that fields exactly the company is not a shelf -- but SMALL ENOUGH TO FIT ON THE
-- SCREEN AT ONCE, which is the binding constraint and worth saying here rather than only in the state.
--
-- A muster is a comparison: this body against that one, and both against what is left in the purse. A
-- shelf that scrolls makes the player hold half the options in their head, and it pushed the Descend
-- button itself below the fold. Eleven rows plus that button is what states/descent.lua's column takes
-- without scrolling, so eleven is the number.
Muster.SHELF_SIZE = 11

-- WHAT A BODY COSTS, AND WHY IT IS NOT FLAT. Draft prices its units flat because there the decision is
-- which unit and whether to chase a duplicate; here the decision is a company, and a company is a trade
-- between how many go down and how good they are. A flat price does not ask that question -- it just
-- meters out eight bodies -- so the budget would be a number on screen that never once refused anything.
--
-- Priced off the blueprint's own `tier`, which is already the game's statement of how far up the ladder a
-- body sits: the seven generic class templates are tier 2 and the discipline exemplars tier 3, so the
-- shelf reads as plain bodies at one coin and specialists at two. Derived rather than authored, so a
-- character retiered in data cannot leave a stale price here.
function Muster.costOf(id)
    local def = Character.defs[id]
    return math.max(1, ((def and def.tier) or 2) - 1)
end

-- The purse. Twelve buys a full company of eight generics with four to spare, six exemplars and nothing
-- else, or any mix between -- which is the trade the tier pricing exists to put in front of the player.
--
-- It can never leave a run unfieldable: COMPANY_MIN bodies at the dearest tier in the pool still come in
-- under this, so there is no shelf that cannot fill a board. tests/descent_muster_spec.lua pins that.
--
-- Its own coin, deliberately NOT the campaign's Vendor price: a character is not on any shelf in the
-- city, and what a run later spends on its floors (a merchant's ware runs to tens of gold) has nothing to
-- say about what a body is worth at the muster.
Muster.BUDGET = 12

-- The candidate roster the shelf draws from: data/draft/pool.lua, read through DraftRun.pool.
--
-- Shared with Draft on purpose. That file is the authored answer to "which characters may a mode hand a
-- player" -- the seven generic class templates, then the subclass exemplars, then the multiclass ones --
-- and it already filters ids whose blueprint has not landed yet (Save.known). A second list would be the
-- same list with a different name and one of them would go stale. What the two modes do with a body
-- after drawing it is where they differ, and that is above, not here.
--
-- The whole pool, not a wave: waves exist to pace a Draft run's ROUNDS, and a descent musters once. Every
-- body the game has is a candidate at the mouth, and the shelf's size is what makes the pick a pick.
function Muster.pool()
    return DraftRun.pool(math.huge)
end

-- The shelf for a run, as a list of character ids. Seeded from the run's own seed through
-- Combat.newRandom -- the same pure-Lua RNG models/draft_shop.lua rolls its store on -- so a shelf is
-- reproducible from the run it belongs to, testable without RNG surprise, and identical on any machine.
--
-- Drawn WITHOUT replacement: a shelf offering the same knight twice would be offering thirteen bodies
-- and telling the player it was fourteen.
function Muster.shelf(seed)
    local pool = Muster.pool()
    local rand = Combat.newRandom(seed or 1)

    -- Partial Fisher-Yates over a copy: draw SHELF_SIZE from the front, leave the rest. Uniform, and it
    -- does not care that the pool is far larger than the shelf.
    local ids = {}
    for i, id in ipairs(pool) do ids[i] = id end
    local n = math.min(Muster.SHELF_SIZE, #ids)
    for i = 1, n do
        local j = i + rand(#ids - i + 1) - 1
        ids[i], ids[j] = ids[j], ids[i]
    end

    local shelf = {}
    for i = 1, n do shelf[i] = ids[i] end
    return shelf
end

-- What `picks` (a list of ids) costs.
function Muster.cost(picks)
    local total = 0
    for _, id in ipairs(picks or {}) do total = total + Muster.costOf(id) end
    return total
end

function Muster.remaining(picks)
    return Muster.BUDGET - Muster.cost(picks)
end

-- Why this particular body cannot be taken, as a short line, or nil when it can. Returns the REASON
-- rather than a boolean because the two refusals are different facts and a screen that says "no" without
-- saying which is a screen the player has to experiment against: one is fixed for the rest of the muster,
-- the other clears the moment something cheaper is put back.
function Muster.refusal(picks, id)
    if #(picks or {}) >= Muster.COMPANY_MAX then
        return "The company is full at " .. Muster.COMPANY_MAX .. "."
    end
    if Muster.costOf(id) > Muster.remaining(picks) then
        return "Not enough left in the purse."
    end
    return nil
end

function Muster.canTake(picks, id)
    return Muster.refusal(picks, id) == nil
end

-- Is this company ready to walk in? See COMPANY_MIN.
function Muster.ready(picks)
    return #(picks or {}) >= Muster.COMPANY_MIN
end

-- The picked ids as instantiated characters, kits intact. Nothing is stripped and nothing is added: what
-- comes back is what data/characters/<id>.lua authors, which is the whole contract of this module.
function Muster.company(picks)
    local company = {}
    for _, id in ipairs(picks or {}) do
        local char = Character.instantiate(id)
        if char then company[#company + 1] = char end
    end
    return company
end

return Muster
