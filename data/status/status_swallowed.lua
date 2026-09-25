-- SWALLOWED: inside something's gullet, alive, and being digested. The Giant Toad's (ability_swallow)
-- and the company's own Gullet (ability_the_gullet); decided on review 2026-09-25 ("The Giant Toad").
--
-- WHAT IT IS, BY PARTS, and every part was already in the game:
--   * Suspended's flags -- cannot act, answer, move or be aimed at. What Suspended does NOT have is the
--     digestion, which is why this is its own status: a suspension protects what it lands on, and this
--     is the one hard control that keeps hurting you while it holds you.
--   * Digesting's feed -- each tick deals its magnitude and heals whoever put it there by exactly what it
--     dealt (status_digesting.lua). Raw, because a stomach is not a blow a breastplate turns.
--   * Combat.swallow / Combat.disgorge -- the body stands on no tile while it is inside (the seam a
--     Chimera's head stands on), and its position is read through the eater's.
--
-- ONE STATUS, EVERY WAY OUT. onApply swallows; onExpire spits, and Status fires onExpire on EVERY removal
-- path. So the time running out, a heavy blow on the eater, a stun on it and its death (all four live in
-- trait_gullet, on the eater's side) are one line each -- remove this -- and none can strand a body off
-- the board. The body comes out Wet, and the eater's meal (the Full the swallow gave it) comes out with
-- it.
--
-- IT NEVER KILLS. A tick that would take the last of a body's health spits it out instead, at 1: the
-- digestion is a clock the company races, and a body dying off the board would be a death nobody could
-- see happen, stand over or revive. The Gullet's loss is tempo and health, never the character.
--
-- NOT A DEBUFF, so Cure does not reach it: nothing is on the body to wash off, it is inside something.
-- The answer is on the eater, and that is the whole fight.
local Combat = setmetatable({}, { __index = function(_, k) return require("models.combat")[k] end })

return {
    name = "Swallowed",
    abbr = "Swl",
    description = "Swallowed: inside a gullet, digested as time passes. Cannot act, be acted on, or answer.",
    color = { 0.52, 0.60, 0.28 }, -- badge tint (bog-green)
    duration = 15, -- three turns at Status.TICKS_PER_TURN; the swallow's own opts set it
    magnitude = 6, -- digestion per turn
    untargetable = true,
    disablesActions = true,
    disablesReactions = true,
    blocksMove = true,
    blocksForcedMove = true,
    interruptsChannel = true,
    onApply = function(ctx)
        local eater = ctx.applier
        if not (ctx.combat and eater and eater.alive) then return end
        ctx.status.eater = ctx.status.eater or eater
        Combat.swallow(ctx.combat, eater, ctx.unit)
    end,
    onTick = function(ctx)
        local n = ctx.accrue(ctx.magnitude)
        if n <= 0 then return end
        local hp = ctx.unit.char.stats.health
        if n >= (hp.current or 0) then
            n = (hp.current or 0) - 1
            if n > 0 then ctx.damage(ctx.unit, n, { "acid" }, { raw = true }) end
            -- Run the clock out rather than removing it here: Status.tick expires what this tick
            -- governs in its second pass, which is the one path that also says so in the log.
            ctx.status.remaining = 0
            return
        end
        local dealt = ctx.damage(ctx.unit, n, { "acid" }, { raw = true }) or 0
        local eater = ctx.status.eater
        if dealt > 0 and eater and eater.alive then ctx.heal(eater, dealt) end
    end,
    -- Something ELSE finished it inside (a poison it went in carrying): the body still has to fall on a
    -- tile, or there is a corpse nobody can see, stand over or revive. The digestion itself never gets
    -- here -- onTick spits first.
    onDeath = function(ctx)
        local body = ctx.unit
        if not (ctx.combat and body and body.swallowedBy) then return end
        local eater = body.swallowedBy
        Combat.disgorge(ctx.combat, body)
        if eater and eater.alive then
            require("models.status").spendStacks(ctx.combat, eater, "status_full", 1)
        end
    end,
    onExpire = function(ctx)
        local body = ctx.unit
        if not (ctx.combat and body and body.swallowedBy) then return end
        local eater = body.swallowedBy
        Combat.disgorge(ctx.combat, body)
        if body.alive then ctx.applyStatus(body, "status_wet") end
        if eater and eater.alive then
            require("models.status").spendStacks(ctx.combat, eater, "status_full", 1)
        end
    end,
}
