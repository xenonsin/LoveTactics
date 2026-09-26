-- THE BLOOD RING: the orc Pit-Fighter's rule, the alpha's fight (data/items/utility/utility_the_blood_ring.lua).
-- Approved as pitched (2026-09-26, "The Orcs of Wrath"); Keno made the pit-fighter the ALPHA and the Warchief
-- the elite. Wrath's house is the Colosseum, and this is its fight in the rift.
--
--   THE RING       the orcs he brought line the board's edge (Spectating) and do not fight. A company body that
--                  ends its turn beside one is shoved back toward the centre and struck.
--   THE CHALLENGE  each turn he ends, he names the company body with the most health as his challenger, and
--                  takes half damage from everyone else (status_the_challenge; Status.damageTakenScale). Healing
--                  is a choice about who fights him.
--   THE CROWD      whenever a body falls, either side, one spectator steps in to fight; when he falls, the whole
--                  crowd does.
local SHOVE = 2

local function name(u) return (u and u.char and u.char.name) or "It" end

local function spectators(combat, u)
    local Status = require("models.status")
    local out = {}
    for _, other in ipairs(combat.units or {}) do
        if other.alive and other.side == u.side and Status.has(other, "status_spectating") then out[#out + 1] = other end
    end
    return out
end

-- Every walkable, empty tile on the board's edge.
local function ringTiles(combat)
    local Combat = require("models.combat")
    local tiles = combat.arena and combat.arena.tiles or {}
    local h = #tiles
    local w = h > 0 and #tiles[1] or 0
    local out = {}
    for y = 1, h do
        for x = 1, w do
            if (x == 1 or y == 1 or x == w or y == h) and Combat.footprintFree(combat, 1, 1, x, y) then
                out[#out + 1] = { x = x, y = y }
            end
        end
    end
    return out
end

-- Name the company body with the most health as the challenger.
local function nameChallenger(ctx)
    local u, combat = ctx.unit, ctx.combat
    local Combat = require("models.combat")
    local Status = require("models.status")
    local best
    for _, other in ipairs(combat.units or {}) do
        if other.alive and other.side ~= u.side and not Combat.isOffTile(other) and not other.summoner then
            if not best or other.char.stats.health.current > best.char.stats.health.current then best = other end
        end
    end
    for _, other in ipairs(combat.units or {}) do
        if other ~= best and Status.has(other, "status_challenger") then Status.remove(combat, other, "status_challenger") end
    end
    if not best then return end
    ctx.applyStatus(u, "status_the_challenge")
    local s = Status.get(u, "status_the_challenge")
    if s and s.exempt ~= best then
        s.exempt = best
        ctx.applyStatus(best, "status_challenger")
        ctx.log("action", string.format("%s names %s the challenger.", name(u), name(best)), u)
    end
end

local function stepIn(ctx, body)
    ctx.clearStatus(body, "status_spectating")
    ctx.log("action", string.format("The crowd roars. %s steps into the ring.", name(body)), body)
end

return {
    name = "The Blood Ring",
    description = "Its crowd shoves back whoever ends a turn beside it and joins when a body falls. Takes half from all but its challenger.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and u.alive and combat) then return end
        local Combat = require("models.combat")
        local ring = ringTiles(combat)
        for _, other in ipairs(combat.units or {}) do
            local fp = other.char and other.char.footprint
            if other.alive and other ~= u and other.side == u.side and other.char and other.char.race == "orc"
                and not (fp and ((fp.w or 1) > 1 or (fp.h or 1) > 1)) then
                local pick, pickD, pickI
                for i, t in ipairs(ring) do
                    local d = Combat.cellGap(t.x, t.y, other)
                    if not pickD or d < pickD then pick, pickD, pickI = t, d, i end
                end
                if pick then
                    table.remove(ring, pickI)
                    Combat.teleportUnit(combat, other, pick.x, pick.y, { silent = true })
                end
                ctx.applyStatus(other, "status_spectating")
            end
        end
        nameChallenger(ctx)
    end,
    onTurnEnd = nameChallenger,
    onAnyTurnEnd = function(ctx)
        local u, combat, actor = ctx.unit, ctx.combat, ctx.actor
        if not (u and u.alive and actor and actor.alive and actor.side ~= u.side) then return end
        local Combat = require("models.combat")
        for _, watcher in ipairs(spectators(combat, u)) do
            if Combat.unitGap(watcher, actor) <= 1 then
                Combat.knockback(combat, watcher, actor, SHOVE)
                local blow = math.max(1, Combat.flatStat(watcher, "damage"))
                Combat.dealFlatDamage(combat, actor, blow, { "impact", "physical" }, "The Ring", watcher)
                ctx.log("action", string.format("The crowd shoves %s back into the ring.", name(actor)), actor)
                return
            end
        end
    end,
    onAnyDeath = function(ctx)
        local u, combat, fallen = ctx.unit, ctx.combat, ctx.fallen
        if not (u and u.alive and fallen) then return end
        local crowd = spectators(combat, u)
        if #crowd == 0 then return end
        local Combat = require("models.combat")
        table.sort(crowd, function(a, b) return Combat.unitGap(a, u) < Combat.unitGap(b, u) end)
        stepIn(ctx, crowd[1])
    end,
    onDeath = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return end
        for _, body in ipairs(spectators(combat, u)) do stepIn(ctx, body) end
    end,
}
