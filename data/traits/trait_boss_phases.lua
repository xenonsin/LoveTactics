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
--   fell      { target, name }  THE SCRIPTED BEAT: the bearer crosses the board to the body named by
--                               `target` (a character id) and puts it down where it stands. Blink
--                               first, so the move is something the player watches happen and not a
--                               death that arrives from off screen, then Combat.fell -- outside the
--                               damage pipeline, so no guardian intercepts it, no barrier eats it and
--                               nothing raises the body again this battle (see models/combat.lua's
--                               Combat.fell for the full argument). `name` is what the log calls it,
--                               because an unanswerable thing that arrives unnamed reads as a bug.
--
--                               IT IS NOT AN ABILITY, and that is deliberate. An ability is targeted,
--                               previewed, resisted and answered -- every seam that makes the rest of
--                               this game fair is a seam a scripted beat can fail at. A body the story
--                               requires on a stretcher cannot be left standing because somebody had a
--                               ward up. Author it here, where nothing can refuse it, and pay for it by
--                               telegraphing the STAGE rather than the strike.
--
--                               Does nothing at all when the named character is not on the board, so a
--                               boss carrying this script stays legal in any fight its scene is not in.
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
    fell   = function(ctx, r)
        local victim = r.target and ctx.unitOf(r.target)
        if not victim then return end
        -- Arrive first. The tile is picked beside the victim rather than on it, and a hemmed-in body is
        -- reached from wherever the bearer already stands -- the blink is the beat's staging, not its
        -- mechanism, so failing to find ground must not cost the beat.
        local x, y = ctx.openTileNear(victim.x, victim.y)
        if x then ctx.teleport(x, y) end
        -- Authored `text` wins, like every other narrative line in a phase table; the fallback only has
        -- to be legible, not good, because a beat worth scripting is a beat somebody wrote a line for.
        ctx.log("action", r.text or string.format("%s: %s falls.",
            r.name or "The strike", victim.char.name or "the body"), { ctx.unit, victim })
        ctx.fell(victim)
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
