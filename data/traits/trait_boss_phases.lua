-- A general boss "phase" rule: declarative health-threshold responses on the onDamaged hook.
--
-- This is a data-driven generalization of the Hollow Crown (data/traits/trait_hollow_crown.lua) and
-- Rising Wrath (data/traits/trait_wrath_rising.lua). It follows the Crown's shape exactly -- fractions
-- of max health, `ctx.trait.stacks` as the phase cursor, a while-loop so one huge blow crosses several
-- thresholds at once -- but the effect at each threshold is a LIST of typed `responses` read from DATA,
-- not one hard-coded summon. So a boss gets phased behavior by authoring a relic, no new Lua:
--   * the Hollow Crown is three { kind = "summon" } phases,
--   * Rising Wrath is one { kind = "enrage" } phase.
-- We ADD this alongside those two rather than refactoring them -- both are short, test-pinned, and
-- narratively load-bearing (their headers celebrate being one-hook bespoke rules) -- so this reproduces
-- their shapes for FUTURE bosses without touching the two that ship.
--
-- The phase table lives on the RELIC that grants the trait (ctx.item.phases), so the same trait id
-- drives every boss and each boss's relic carries its own script. See utility_demon_sigil.lua.
--
-- Because onDamaged fires only on a SURVIVOR (Combat.dealFlatDamage dispatches phases in the survivor
-- branch only; a barrier/dodge/parry returns 0 before the dispatch), a blow that KILLS never crosses a
-- threshold: burst the boss past a phase and you skip that threat -- the correct, honest reading, the
-- same one the Crown documents.
--
-- Response kinds:
--   status    { id, opts }      apply/refresh a status on the bearer (arms status_roaring)
--   clear     { id }            strip a status from the bearer (drops status_roaring at the next stage)
--   bonus     { stat, amount }  a flat, permanent per-battle stat bump (ctx.addBonus writes unit.bonus)
--   summon    { id, count }     call bodies onto open tiles beside the bearer, sustained by it
--   transform { id }            the bearer sheds its body for another blueprint's -- the human general
--                               becoming the demon beneath. Same unit, same tile, same health bar; its
--                               kit and board sprite become the shape's (models/transform.lua). Permanent
--                               (nothing reverts a phase transform), so the fight continues in the new
--                               form. Carries the CURRENT health across, so a general phased at 50% opens
--                               its demon stage already half-spent -- the transform changes what it can
--                               do, never how much killing it takes.
--   enrage    { magnitude }     switch on the continuous Rising-Wrath curve for the rest of the fight
--   log       { text }          a line in the combat log
--   mark      { victim, scene,  the bearer picks a body and puts it down ON ITS OWN NEXT TURN, by
--               hitScene,       script rather than by damage. See the paragraph below for why this
--               seconds }       one is armed here and spent elsewhere, and Combat.spendScriptedFell
--                               for the beat it becomes. `victim` is a character id; `scene` is the
--                               line the board owes the player NOW (a full turn of warning),
--                               `hitScene` the one spoken with the blow already landed, and
--                               `seconds` how long the wind-up shake runs.
--
-- THERE IS NO `fell` RESPONSE, AND THERE MUST NOT BE ONE. It existed here briefly and the reason it went
-- is worth keeping: a phase crosses inside onDamaged, which runs inside the resolution of the blow that
-- crossed it, so ANYTHING a phase does lands on top of the player's own attack with no turn boundary
-- between them. That is fine for a status or a stat bump, which are state; it is wrong for an ACT. A
-- boss that is meant to do something dramatic arms a marker here and spends it on its own turn -- which
-- is exactly what `mark` is, and the whole of what it does here. The ACT it becomes is
-- Combat.spendScriptedFell, called from Combat.startTurn once a turn boundary has actually passed.
local RESPONSES = {
    status = function(ctx, r) ctx.applyStatus(ctx.unit, r.id, r.opts) end,
    clear  = function(ctx, r) ctx.clearStatus(ctx.unit, r.id) end,
    bonus  = function(ctx, r) ctx.addBonus(r.stat, r.amount) end,
    summon = function(ctx, r)
        for _ = 1, (r.count or 1) do
            local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
            if x then ctx.summon(r.id, x, y) end
        end
    end,
    transform = function(ctx, r) if r.id then ctx.transform(r.id) end end,
    -- Set the magnitude the curve is worth at death's door; the onDamaged body below re-scales the
    -- bearer's damage off missing health every later survived blow (ctx.trait.applied tracks paid).
    enrage = function(ctx, r) ctx.trait.enrageMagnitude = r.magnitude end,
    log    = function(ctx, r) if r.text then ctx.log("system", r.text) end end,
    -- ARM, NEVER ACT (see the paragraph above). Everything this writes is state: a table on the bearer
    -- naming who it has picked, and the line the board owes the player before anything is spent. The
    -- crossing and the felling happen a turn later, in Combat.spendScriptedFell.
    --
    -- A plain field rather than a status, because a status is a thing the fight can read, refresh,
    -- cleanse and count -- and this is none of those. It is a page of the script the boss is holding.
    mark   = function(ctx, r)
        ctx.unit.scriptedFell = { victim = r.victim, hitScene = r.hitScene, seconds = r.seconds }
        -- Queued on the COMBAT rather than played from here: data is pure logic and must not reach into
        -- the UI, and the scene has to wait for the blow that armed it to finish resolving anyway.
        -- states/battle.lua plays it at the next turn boundary and clears it. Nil-safe on purpose: no
        -- scene, no beat, the felling still lands.
        if r.scene and ctx.combat then ctx.combat.pendingScene = r.scene end
    end,
}

return {
    name = "Demon Ascendant",
    description = "Answers each wound with the next stage of the fight.",
    onDamaged = function(ctx)
        -- The script rides on the granting relic, so one trait id serves every boss.
        local phases = (ctx.item and ctx.item.phases) or ctx.def.phases or {}
        if #phases == 0 and not ctx.trait.enrageMagnitude then return end

        local hp = ctx.unit.char.stats.health
        local max = hp.max or 0
        if max <= 0 then return end
        local fraction = (hp.current or 0) / max

        -- Cross as many thresholds as this one blow spans, running each phase's responses in order. A
        -- crossing may turn the enrage curve ON (the `enrage` response sets ctx.trait.enrageMagnitude),
        -- so the curve is applied AFTER the loop -- which lets the same blow that crosses 33% also land
        -- the first tick of enrage.
        while ctx.trait.stacks < #phases
              and fraction <= (phases[ctx.trait.stacks + 1].at or 0) do
            ctx.trait.stacks = ctx.trait.stacks + 1
            for _, r in ipairs(phases[ctx.trait.stacks].responses or {}) do
                local run = RESPONSES[r.kind]
                if run then run(ctx, r) end
            end
        end

        -- Continuous enrage (the wrath_rising curve, folded in): once opened, every survived blow
        -- re-scales the bearer's damage off how much health is now gone. `applied` holds the bonus paid
        -- so far, so each hit adds only the difference; the badge shows the running number. Monotonic on
        -- purpose (want > have): healing it does not calm it down.
        if ctx.trait.enrageMagnitude then
            local gone = 1 - fraction
            local want = math.floor(ctx.trait.enrageMagnitude * gone)
            local have = ctx.trait.applied or 0
            if want > have then
                ctx.addBonus("damage", want - have)
                ctx.trait.applied = want
                ctx.applyStatus(ctx.unit, "status_enraged", { magnitude = want })
            end
        end
    end,
}
