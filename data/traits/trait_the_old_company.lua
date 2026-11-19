-- THE OLD COMPANY: the drill a dead company still keeps (2026-11-19, the creature identity pass). Worn by
-- the Skeleton Knight and the Skeleton Archer through one piece, utility_company_bones.lua, because the
-- rule is about the two of them TOGETHER -- which is the whole of what the audit found missing. Each body
-- alone was "hit it until it dies", with one shared answer (a mace). As a company they ask two more things:
--
--   * THE KNIGHTS GUARD THE BOWS. While a knight of the company stands, every bow of it on the same side
--     is Shielded (status_shielded: half damage). The badge is laid at the bell, refreshed at each of the
--     company's turns, and lifted the moment the last knight falls. So the archer is the last thing to
--     kill, not the first, and the knights are what the mace is for. A knight's verb that outlived the
--     knight -- the review's own phrase for the lever.
--   * THE BOWS MARK THE HAMMER. At the start of an archer's turn, when no foe already wears Mark, it Marks
--     the nearest foe holding an impact weapon -- the one body in the company that can break a frame. The
--     whole company's rules prefer a Marked foe (their `ai` blocks), so bringing the answer means guarding
--     it. The Mark is the game's own (status_mark): the player sees who is being hunted, and a Cure lifts it.
--
-- KNIGHT OR BOW IS READ OFF THE BODY'S CLASS (the dead keep their class, 2026-09-25): a knight guards,
-- anything else wearing the piece is a bow. Hooks only -- no engine seam needed, since damageTakenScale is
-- read off the status where every blow is already mitigated.
local Status = require("models.status")

local SHIELD = "status_shielded"
local MARK = "status_mark"

local function isKnight(u)
    return u and u.char and u.char.class == "knight"
end

local function standing(u)
    local hp = u and u.alive and u.char and u.char.stats and u.char.stats.health
    return hp and (hp.current or 0) > 0
end

local function wearsCompany(u)
    return require("models.trait").has(u, "trait_the_old_company")
end

-- Lay or lift every bow's Shielded on `side`, by whether any knight of the company still stands there.
local function refresh(combat, side)
    local guarded = false
    for _, u in ipairs(combat.units or {}) do
        if u.side == side and standing(u) and isKnight(u) and wearsCompany(u) then guarded = true break end
    end
    for _, u in ipairs(combat.units or {}) do
        if u.side == side and standing(u) and not isKnight(u) and wearsCompany(u) then
            local has = Status.has(u, SHIELD)
            if guarded and not has then
                Status.apply(combat, u, SHIELD)
            elseif not guarded and has then
                Status.remove(combat, u, SHIELD)
            end
        end
    end
end

-- Does `u` carry a weapon that strikes with impact -- a mace, a hammer, a maul, a club?
local function holdsImpact(u)
    for _, item in ipairs(require("models.character").eachItem(u.char)) do
        if item.type == "weapon" then
            for _, tag in ipairs(item.tags or {}) do
                if tag == "impact" then return true end
            end
        end
    end
    return false
end

local function markTheHammer(ctx)
    local combat, me = ctx.combat, ctx.unit
    local Combat = require("models.combat")
    local best, bestGap
    for _, u in ipairs(combat.units or {}) do
        if u.side ~= me.side and standing(u) then
            if Status.has(u, MARK) then return end -- somebody is already being hunted
            if holdsImpact(u) then
                local gap = Combat.unitGap(me, u)
                if not bestGap or gap < bestGap then best, bestGap = u, gap end
            end
        end
    end
    if not best then return end
    if Status.apply(combat, best, MARK, { applier = me }) then
        ctx.log("action", string.format("%s marks %s: the dead know who brought the hammer.",
            (me.char and me.char.name) or "It", (best.char and best.char.name) or "a foe"), { me, best })
    end
end

return {
    name = "The Old Company",
    grade = 1.0, -- weighed beside the rule (Grade.traitValue reads it): half damage on the archers while a knight stands
    description = "While a Skeleton Knight stands, its archers are Shielded. An archer Marks the nearest foe holding an impact weapon.",
    -- Nothing here is the body answering a blow, so a stunned knight still guards and a stunned bow's
    -- shelter still lifts when its knight falls.
    notAReaction = true,
    onCombatStart = function(ctx) refresh(ctx.combat, ctx.unit.side) end,
    onTurnStart = function(ctx)
        refresh(ctx.combat, ctx.unit.side)
        if not isKnight(ctx.unit) then markTheHammer(ctx) end
    end,
    onDeath = function(ctx) refresh(ctx.combat, ctx.unit.side) end,
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if fallen and fallen.side == ctx.unit.side then refresh(ctx.combat, ctx.unit.side) end
    end,
}
