-- ITEM HOOKS: the handful of pieces of gear that do something BETWEEN fights rather than inside one.
--
-- WHY THIS EXISTS AT ALL. Almost every item in the game acts through the combat stack -- a bonus, a
-- resist, a trait, an activeAbility -- and nothing on an expedition ever has to ask a grid a question.
-- Three do: a larder that feeds its bearer after every fight cleared, a purse that doubles what a fight
-- pays, and a vigil that gives back mana. All three arrived as run RELICS (models/relic.lua, parked
-- 2026-09-17) where the expedition loop already had a dispatcher to hang them on; converting them to
-- gear meant the loop had to be able to ask the roster's items the same question the run's pile used to
-- answer. This is that, and it is deliberately the smaller twin of Relic.dispatch rather than a general
-- event bus: one event, no per-item scratch, no stacking ladder.
--
-- HOW IT DIFFERS FROM THE SHELF IT REPLACED, and both differences are the point:
--   * A RELIC WAS HELD BY THE RUN, so its hook ran once and reached the whole company. An item is worn
--     by a BODY, so a hook runs once PER BEARER and `ctx.char` is the body that brought it. Two members
--     carrying larders feed twice -- which is the stacking story, told in loadout slots instead of in
--     a `base + (n-1) * step` ladder.
--   * A relic could not be lost mid-run. Gear can be swapped at any stop, so the roster is walked
--     fresh on every dispatch rather than cached at the mouth of the stair.
--
-- HEADLESS-SAFE, like every model: no love.graphics, no love.math at require-time. The ctx carries every
-- helper a hook is allowed to reach for (see `ctxFor`), so a data file never touches a model directly --
-- the same contract a trait's `fx` and a relic's ctx keep, for the same reason: a blueprint that can
-- reach the whole tree is a blueprint no spec can drive.

local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")

local ItemHook = {}

-- The events an item may declare. One, for now, and it is listed rather than left implicit so a
-- misspelled hook name in a blueprint is a thing a spec can catch -- a field nothing ever reads is
-- otherwise indistinguishable from a field that works (tests/item_rules_spec.lua asserts it).
ItemHook.EVENTS = { "encounterCleared" }

-- ---------------------------------------------------------------------------
-- The pools a hook may move
-- ---------------------------------------------------------------------------

local function pool(char, stat)
    local p = char and char.stats and char.stats[stat]
    return (type(p) == "table") and p or nil
end

-- Give `amount` back, never past the ceiling, and answer with what actually landed -- so a hook can say
-- "+6 health" and mean it rather than quoting what it tried to give. A body already full takes 0, which
-- is what lets a larder stay quiet instead of announcing nothing.
local function restore(char, stat, amount)
    local p = pool(char, stat)
    if not (p and p.max) then return 0 end
    local before = p.current or 0
    p.current = math.min(p.max, before + (amount or 0))
    return p.current - before
end

-- Take `amount` off a pool as a piece of gear's standing toll, FLOORED AT 1: a price wounds but never
-- fells. Inherited verbatim from the relic shelf's `drain`, and for the reason its header records -- a
-- wipe has to come from the fight, not from having carried a cursed purse down the stair.
local function drain(char, stat, amount)
    local p = pool(char, stat)
    if not (p and p.max) then return 0 end
    local before = p.current or 0
    p.current = math.max(1, before - (amount or 0))
    return before - p.current
end

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

local function ctxFor(ctx)
    ctx.party = ctx.party or (ctx.player and ctx.player.roster) or {}
    ctx.notify = ctx.notify or function() end
    ctx.say = function(msg) ctx.notify(msg) end
    -- THE UNPAID TITHE gags every restore its bearer would receive: no larder, no vigil, no post-fight
    -- mend. Enforced HERE, at the one helper every hook gives back through, so none of the giving items
    -- has to know the Tithe exists -- a larder on a tithed body simply pays 0 and says nothing, which is
    -- what "recovers nothing" means.
    --
    -- PER BEARER, which is the whole difference from the relic this came off. The relic read the RUN's
    -- rules and gagged the entire company; the item reads the rules of the body being restored, so a
    -- tithed knight goes hungry at a stop that feeds the other three. `char` is the body the hook is
    -- giving TO, which is not always the bearer of the larder -- so the gag is asked of the receiver.
    ctx.restore = ctx.restore or function(char, stat, amount)
        local rules = Item.rulesFor(char)
        if rules and rules.noRecovery then return 0 end
        return restore(char, stat, amount)
    end
    ctx.drain = ctx.drain or drain
    ctx.addGold = ctx.addGold or function(amount)
        if ctx.player and amount and amount ~= 0 then Player.addGold(ctx.player, amount) end
    end
    return ctx
end

-- Fire `event` for every piece of gear on every member of the company that declares it.
--
-- `ctx.char` IS REBOUND PER BEARER and is the whole of how an item hook is scoped. A hook reads it to
-- know whose larder it is; forgetting to would feed the party instead of the carrier, which is the one
-- mistake that turns a converted relic back into the relic it was converted from.
--
-- Order is roster order, then grid order within a body -- stable, so a run seeded the same way pays out
-- the same way (the property models/encounter.lua's pool sorting exists to protect).
function ItemHook.dispatch(event, ctx)
    ctx = ctxFor(ctx or {})
    for _, char in ipairs(ctx.party) do
        for _, item in ipairs(Character.eachItem(char)) do
            local hook = item[event]
            if type(hook) == "function" then
                ctx.char = char
                hook(item, ctx)
            end
            -- ...AND THE HEX ON THE PIECE, which may declare the same hooks (models/curse.lua). A curse
            -- speaks the item's own vocabulary everywhere else -- `bonus`, `rules`, `traits`,
            -- `openingBoon` are all folded beside the piece's own -- and this is that rule reaching the
            -- one seam that runs BETWEEN fights rather than inside one. The Spreading needs it: a hex
            -- that creeps to the next cell has to fire somewhere, and the end of a fight is the only
            -- moment on an expedition that a grid is quiet enough to rewrite.
            --
            -- Called with the ITEM, not the curse, so a hook can reach the piece it is riding -- which
            -- is what a spread has to know (Curse.spreadWithin takes the cell it starts from).
            local curse = require("models.curse").of(item)
            local chook = curse and curse[event]
            if type(chook) == "function" then
                ctx.char = char
                chook(item, ctx)
            end
        end
    end
    ctx.char = nil
    return ctx
end

return ItemHook
