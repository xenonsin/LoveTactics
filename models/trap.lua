-- Traps: tile objects placed in a combat arena, owned by a side. A trap is hidden from the
-- owner's opponents unless one of their units carries a "detect traps" item within range; a
-- unit that paths over an opposing trap triggers it (damage or a status effect, single-target
-- or AoE), and a revealed trap has HP and can be attacked down. Pure logic (no love.graphics
-- beyond the tolerant Sprite loader), so it loads under the headless tests.
--
-- Blueprints live in data/traps/<id>.lua and expose:
--   * health              -- HP; how much damage destroys the trap (default 1)
--   * onTrigger(ctx)      -- fired when an opposing unit enters the tile; ctx.victim is that unit
--   * onDestroy(ctx)      -- fired when the trap is damaged to 0 HP
--   * consumedOnTrigger   -- default true: the trap is spent after one trigger; false = persistent
--   * tags                -- descriptive tags (routed through damage mitigation like item tags)
--
-- `ctx` carries { combat, trap, victim } plus bound, headless-safe helpers (damage /
-- applyStatus / unitsNear). Combat/Status are pulled through a LAZY require so this module
-- never sits in a load-time require cycle (combat.lua requires this module).

local Registry = require("models.registry")
local Sprite = require("models.sprite")

local Trap = {}

Trap.defs = Registry.load("data/traps", "data.traps")

Trap.DETECT_TAG = "detect traps"
Trap.DEFAULT_DETECT_RADIUS = 2

local function manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Build the effect context handed to a trap def's hooks. Combat/Status are required lazily
-- (at call time, not load time) so combat.lua -> trap.lua stays a one-way dependency.
local function ctxFor(combat, trap, victim)
    local Combat = require("models.combat")
    local Status = require("models.status")
    return {
        combat = combat,
        trap = trap,
        victim = victim,
        damage = function(tgt, amount, tags)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, amount, tags, trap.name or trap.id)
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        -- SINK A HEX INTO ONE PIECE OF THE VICTIM'S KIT (models/curse.lua). The trap's version of
        -- fx.curse, and the vector a curse is most at home on: a thing laid in the ground that gets into
        -- what you are carrying. `id` names the curse; omitted, the rift's shallowest is rolled.
        -- Returns the item and the id, or nil when the grid had nothing a hex could take hold of.
        curse = function(tgt, id)
            if not tgt then return nil end
            return Combat.curseItem(combat, tgt, id)
        end,
        -- ...AND THE SAME VECTOR POINTED AT THE BODY RATHER THAN THE KIT (models/injury.lua). A pit
        -- breaks a leg, a gas takes a lung -- and unlike every other thing a trap does, this one
        -- outlives the fight.
        --
        -- IT RECORDS RATHER THAN CHARGES, which is the same split `battle.fallen` already keeps and the
        -- reason it is not simply a call to Injury.inflict. An injury is keyed by character id on the
        -- PLAYER, and the combat model has no player and must not grow one: Combat.unreservedMax is
        -- asked about summons, enemies and duel rosters that have no player behind them at all. So the
        -- trap writes an intent onto the combat object and states/game.lua's inflictInjuries drains it
        -- on the way out, where the player is in scope -- which also means a trap in a duel or a draft
        -- match records into a list nobody reads, and correctly costs nobody a bone.
        --
        -- Only a body with an id the save will still know tomorrow can carry one, which is the same
        -- filter Injury.inflict applies -- stated here too so a summon standing on a pit records
        -- nothing rather than recording a row that is silently dropped later.
        injure = function(tgt, id)
            local charId = tgt and tgt.char and tgt.char.id
            if not charId then return nil end
            combat.dealtInjuries = combat.dealtInjuries or {}
            combat.dealtInjuries[#combat.dealtInjuries + 1] = { charId = charId, kind = id }
            return charId
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
    }
end

-- Place a trap of blueprint `id` at (x, y), owned by `side` ("party"/"enemy"). Appends a
-- runtime trap to combat.traps and returns it -- or nil if the tile can't hold one. A trap can't
-- sit on impassable terrain (a solid obstacle) -- nothing paths over a wall to trigger it -- nor
-- on a tile a unit already occupies, so this refuses either. The authoritative backstop for every
-- caller (authored arena data, fx.placeTrap); Combat.useItem also blocks the player's tile-target
-- cast earlier so no turn is wasted on it.
function Trap.place(combat, x, y, id, side, opts)
    opts = opts or {}
    local def = Trap.defs[id]
    assert(def, "unknown trap id: " .. tostring(id))

    local tiles = combat.arena and combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    if cell and not cell.walkable then return nil end
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.x == x and u.y == y then return nil end -- a unit already stands here
    end

    local tags = {}
    for _, t in ipairs(def.tags or {}) do tags[#tags + 1] = t end

    local trap = {
        id = id,
        name = def.name,
        sprite = Sprite.load(def.sprite),
        x = x, y = y,
        side = side or "enemy",
        health = def.health or 1,
        maxHealth = def.health or 1,
        amount = opts.amount, -- item-level-scaled trigger magnitude (nil for an arena-authored trap)
        -- Who set it, when a unit did (nil for anything the arena was authored with). Distinct from
        -- `side`, which is all a trap needed for as long as the only question was "does this bite me":
        -- a standing rule that keys off the TRAPPER rather than the faction -- the Poacher's Quarry's
        -- Due, marking whatever its own snares catch -- cannot be answered by a side alone, because two
        -- hunters on one side do not share each other's charms.
        placer = opts.placer,
        alive = true,
        def = def,
        tags = tags,
    }
    combat.traps = combat.traps or {}
    combat.traps[#combat.traps + 1] = trap

    -- THE PATIENT LINE (Sela's bound relic): a trapper carrying `trapSpread` lays wider ground than she
    -- aims at -- every trap she sets also takes the four tiles around it, for the rest of the fight.
    -- The flag lives on the PLACER rather than on the relic so it survives the relic being put away,
    -- and is read here rather than in the relic so it reaches traps set long after it was pressed --
    -- which is the half the design specifically asked for.
    --
    -- `opts.spread` marks the copies. Without it each neighbour would lay four more and the board would
    -- fill with one press; with it the spread is exactly one tile deep, always.
    if not opts.spread and opts.placer and opts.placer.trapSpread then
        for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            Trap.place(combat, x + step[1], y + step[2], id, side,
                { amount = opts.amount, placer = opts.placer, spread = true })
        end
    end
    return trap
end

-- The living trap on a tile, or nil.
function Trap.at(combat, x, y)
    for _, t in ipairs(combat.traps or {}) do
        if t.alive and t.x == x and t.y == y then return t end
    end
    return nil
end

-- The best "detect traps" radius among a character's items, or nil if it carries no detector.
-- Uses `pairs`, not `ipairs`: the 3x3 grid is a sparse array (a removed item leaves a gap), and
-- ipairs would stop at the first empty cell and miss a detector sitting past it. Order doesn't matter
-- here -- we take the max radius across every carried detector.
local function detectorRadius(char)
    local best
    for _, item in pairs(char.inventory or {}) do
        if hasTag(item.tags, Trap.DETECT_TAG) then
            local r = item.detectRadius or Trap.DEFAULT_DETECT_RADIUS
            if not best or r > best then best = r end
        end
    end
    return best
end

-- Is `trap` visible to `side`? Always to its owner; to opponents only when some living unit of
-- `side` carries a "detect traps" item within that item's detectRadius (Manhattan) of the trap.
function Trap.visibleTo(combat, trap, side)
    if not trap.alive then return false end
    if side == trap.side then return true end
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == side then
            local r = detectorRadius(u.char)
            if r and manhattan(u.x, u.y, trap.x, trap.y) <= r then return true end
        end
    end
    return false
end

-- Living traps visible to `side` (for the renderer / targeting).
function Trap.revealedTo(combat, side)
    local out = {}
    for _, t in ipairs(combat.traps or {}) do
        if Trap.visibleTo(combat, t, side) then out[#out + 1] = t end
    end
    return out
end

-- Trigger `trap` against `victim` (the unit that entered its tile). No-op unless the victim is
-- alive and on the opposing side. Runs the def's onTrigger and spends the trap unless the def
-- opts out with consumedOnTrigger = false. Returns true if it fired.
function Trap.trigger(combat, trap, victim)
    if not (trap.alive and victim and victim.alive) then return false end
    if victim.side == trap.side then return false end
    local Combat = require("models.combat")
    Combat.logEvent(combat, "trap",
        string.format("%s triggers %s!", (victim.char and victim.char.name) or "Unit", trap.name or "a trap"))
    if trap.def.onTrigger then trap.def.onTrigger(ctxFor(combat, trap, victim)) end
    -- QUARRY'S DUE (the Poacher's): a trapper whose charm declares `marksTrapped` paints whatever its
    -- own snares catch. Keyed off `trap.placer`, not off the side, so one hunter's charm never marks
    -- for the hunter standing beside it -- and fired after the trap's own effect, so a snare that
    -- Roots leaves its victim Rooted AND Marked rather than racing its own status.
    --
    -- This is the wiring that makes the discipline one thing: the traps were already on the shelf and
    -- the execute was already on the shelf, and until now nothing connected them.
    local Trait = require("models.trait")
    if trap.placer and trap.placer.alive and victim.alive and Trait.flag(trap.placer, "marksTrapped") then
        require("models.status").apply(combat, victim, "status_mark", { applier = trap.placer })
    end
    if trap.def.consumedOnTrigger ~= false then trap.alive = false end
    return true
end

-- Dry-run a trap blueprint's onTrigger against a stand-in victim to report what crossing its tile
-- would do -- the raw (pre-mitigation) damage it deals and any status it applies -- WITHOUT a real
-- combat. Mirrors Combat.abilityOutput's approach for ability items: the trap's own effect is the
-- source of truth, so a data-only trap (spike = damage, snare = a status) is described without its
-- numbers being duplicated anywhere. pcall-guarded so a data quirk can never crash a tooltip.
-- Returns { damage, statuses = { { id, def } } }, or nil for an unknown id. `amount` (optional) is the
-- item-level-scaled magnitude the trap was placed with, so the preview quotes the damage it will really
-- deal at that upgrade level rather than the blueprint's base.
function Trap.preview(id, amount)
    local def = Trap.defs[id]
    if not def then return nil end
    local Status = require("models.status")
    local out = { damage = 0, statuses = {} }
    local victim = { alive = true, side = "enemy", char = { name = "target" } }
    local trap = { id = id, name = def.name, def = def, tags = def.tags or {}, amount = amount }
    local ctx = {
        combat = nil, trap = trap, victim = victim,
        damage = function(_, amount) out.damage = out.damage + (amount or 0); return amount or 0 end,
        applyStatus = function(_, sid)
            out.statuses[#out.statuses + 1] = { id = sid, def = Status.defs[sid] }
            return nil
        end,
        unitsNear = function() return { victim } end,
    }
    if def.onTrigger then pcall(def.onTrigger, ctx) end
    return out
end

-- Damage a (revealed) trap. Destroys it at 0 HP, running the def's onDestroy. Returns the
-- amount applied.
function Trap.damage(combat, trap, amount)
    if not trap.alive then return 0 end
    trap.health = trap.health - amount
    if trap.health <= 0 then
        trap.health = 0
        trap.alive = false
        local Combat = require("models.combat")
        Combat.logEvent(combat, "trap", string.format("%s is destroyed.", trap.name or "A trap"))
        if trap.def.onDestroy then trap.def.onDestroy(ctxFor(combat, trap, nil)) end
    end
    return amount
end

-- ---------------------------------------------------------------------------
-- Traps on the FLOOR, above the arena
-- ---------------------------------------------------------------------------

-- Everything above this line is a trap inside a BATTLE -- a tile object owned by a side, placed by an
-- ability, destructible, resolved against combat units. What follows is the other kind: a trap laid in
-- the dungeon itself, met while walking a floor rather than while fighting on one.
--
-- THEY SHARE THE BLUEPRINTS AND THE DETECTOR, AND NOTHING ELSE. `data/traps/*.lua` already describes
-- what a spike trap is and how hard it bites, and `Trap.DETECT_TAG` already describes the charm that
-- finds one -- so a corridor trap reads its damage off the same file a planted one does, and the Trap
-- Sense Charm works in both places, which is what a player would assume the moment they own one.
--
-- WHAT THEY DO NOT SHARE is the resolution. A floor trap has no combat to run `onTrigger` against:
-- there is no grid, no initiative, no victim unit. So it is not called -- the floor reads the def's
-- `damage` and `tags` directly and spends them on the company through Trap.springOn.

-- THE BEST DETECTOR IN THE PACKS, as a radius, or 0 for a company carrying none.
--
-- BEST RATHER THAN SUM, exactly as Player.visionBonus is: two charms are not twice the warning, and a
-- company that has found a better one should feel the upgrade rather than the stack.
--
-- WALKS THE WHOLE ROSTER AND THE STASH, which is the same reach Player.visionBonus takes and is right
-- for the same reason: this is a thing the company OWNS rather than a thing a body wields, and which
-- pocket it is in is not a decision anybody made.
function Trap.detectRadiusFor(player)
    local Character = require("models.character")
    local best = 0
    local function consider(item)
        if item and hasTag(item.tags, Trap.DETECT_TAG) then
            local r = item.detectRadius or Trap.DEFAULT_DETECT_RADIUS
            if r > best then best = r end
        end
    end
    for _, char in ipairs((player and player.roster) or {}) do
        for _, item in ipairs(Character.eachItem(char)) do consider(item) end
    end
    for _, item in ipairs((player and player.stash) or {}) do consider(item) end
    return best
end

-- WHICH BLUEPRINTS CAN BE LAID ON A FLOOR: the ones that state a bite in damage. A trap whose whole
-- effect lives in an `onTrigger` closure (a snare that Roots, a charge that knocks back) has nothing to
-- spend out of combat, so it is skipped rather than fired into a context that has no board under it.
-- Sorted, because `pairs` order is unspecified and a floor must lay out the same way twice.
function Trap.floorable()
    local out = {}
    for id, def in pairs(Trap.defs or {}) do
        if (def.damage or 0) > 0 then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-- SPRING ONE ON THE COMPANY, and hand back what it cost as { [charId] = damage } for the readout.
--
-- IT HURTS EVERYBODY WHO WALKED DOWN, which is the honest reading of a corridor: the party is moving as
-- one token on this board, so a pit under that token is a pit under all of them. Spreading it over the
-- company also keeps a trap from being a coin flip that deletes one body -- the damage is real and the
-- decision it feeds is "do I keep walking blind", not "did I lose the priest".
--
-- NEVER TO NOUGHT. A trap on a floor cannot kill: there is no battle to lose, no defeat screen to route
-- to, and a company wiped by a corridor would be a game over arriving with no fight attached to it.
-- One health is the floor, and a company walked down to it is in real trouble without being finished.
-- IT IS NOT MITIGATED, and that is a limit of where it happens rather than a claim about armour.
-- Combat.mitigatedDamage takes a UNIT -- a body standing on a board, with a side, statuses and
-- barriers hanging off it -- and there is no board here: the company is one token walking a floor.
-- Faking a unit to get armour applied would mean inventing the half-dozen fields that function reads
-- and keeping them right forever after, to deliver a number nobody could check.
--
-- So a floor trap bites for exactly what its blueprint says, and the answer to it is the charm that
-- finds it rather than the coat that softens it (Trap.detectRadiusFor). That is also the more honest
-- reading of the fiction: a pit does not care what you are wearing.
-- WHAT SHARE OF A BLUEPRINT'S BITE A FLOOR TRAP ACTUALLY SPENDS, per body.
--
-- MEASURED BY WALKING ONE. A spike trap is authored at 18 damage against a single unit on a battle
-- board. Out here it hits the WHOLE company -- the party is one token and a pit under it is a pit under
-- all four -- so the same number is four times the bill. A floor carries three to five of them
-- (Descent.FLOOR_TRAPS), and a sweep of one floor left a 70-health body on 10: not a cost, a wipe
-- arranged in advance.
--
-- A THIRD. Three traps at six a body is about a quarter of a floor-one company's health for walking a
-- floor blind, which is a real price against a camp that gives back a share and a Charm that avoids it
-- entirely -- and it leaves the company able to take the stair. Re-measure by walking, not by reading:
-- the whole reason this constant exists is that the authored number looked fine on paper.
Trap.FLOOR_SHARE = 0.35

function Trap.springOn(player, def, share)
    local out = {}
    if not (player and def) then return out end
    local raw = math.max(1, math.floor((def.damage or 0) * (share or Trap.FLOOR_SHARE) + 0.5))
    for _, char in ipairs((player and player.roster) or {}) do
        local hp = char.stats and char.stats.health
        if type(hp) == "table" and (hp.current or 0) > 0 then
            -- Clamped to leave one, which is the floor stated in the header.
            local after = math.max(0, math.min(raw, (hp.current or 0) - 1))
            hp.current = hp.current - after
            if after > 0 then out[char.id] = after end
        end
    end
    return out
end

return Trap
