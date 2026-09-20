-- FURY SWIPES, the half that does the counting. The wound itself is data/status/status_fury_swipes.lua
-- and owns what a stack is WORTH; this owns how many there may be and what earns one.
--
-- A BLOW THAT MISSED IS NOT A SWIPE. `onCast` fires on a thrown swing as readily as on a landed one, so
-- without the gate below this would be a rider that cannot miss riding a blow that can -- the exact bug
-- trait_lure's header records paying for once. Gated on the cast having drawn blood, which is also the
-- only thing that makes the word "consecutive" mean anything: a bear that whiffs has broken its own
-- chain, and that is a real thing for an evasive body to play for.
--
-- WHICH THE SUITE CANNOT SEE. tests/skirmish_spec.lua runs under a pinned FORCE_HIT, so under the
-- budget harness nothing ever misses and this gate never fires. It has to be specced directly, against a
-- cast that is made to fail, or the one rule here that depends on accuracy is measured in a world with
-- no accuracy in it.
--
-- THE CAP IS THE BALANCE, and it is priced in the status: four stacks at 2 apiece is 8, which is exactly
-- what status_vulnerable_slash grants for a whole ability. A bear spending four consecutive turns on one
-- body arrives where one spell already is -- never past it. Raising this number is raising the ceiling on
-- the only compounding threat in the game, so it is the first thing to measure and the last thing to
-- move.
--
-- Stateless between blows on purpose. There is no `lastTarget` kept here, because the STATUS is the
-- memory: it is on the body, it decays on its own, and asking it what it is currently worth is the same
-- question as "has this bear been working on you". A cursor kept on the trait would be a second copy of
-- that, free to disagree with the badge the player is reading.
-- The requires live INSIDE the hooks, which is the convention every other file in this folder follows
-- and not a style choice. Trait.defs is built by Registry.load while models/trait.lua is itself still
-- loading, and models/combat.lua requires models/trait.lua -- so a top-level require here reaches into a
-- module that may be half-built, and it is the kind of breakage that shows up as a nil field in one
-- fight rather than as a load error. It also moves table iteration order, which this codebase has been
-- bitten by before.
return {
    name = "Fury Swipes",
    description = "Each landed blow on the same body deepens Fury Swipes, up to 4.",
    maxStacks = 4, -- see the header: four stacks is one authored Vulnerability, and the ceiling
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end -- a swing that drew nothing opened nothing
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive then return end
        if target.side == ctx.unit.side then return end -- it does not work on its own
        local Status = require("models.status")
        local cur = Status.get(target, "status_fury_swipes")
        local have = (cur and cur.magnitude) or 0
        local want = math.min(have + 1, ctx.def.maxStacks or 4)
        -- Re-applied rather than incremented in place, so the refreshed DURATION rides along with the
        -- deeper stack: Status.instantiate takes the opts magnitude and resets the clock together. A
        -- bear that is still working keeps the wound open by working it.
        ctx.applyStatus(target, "status_fury_swipes", { magnitude = want })
        -- Only on the stack that actually deepened. At the cap the animal is still swinging and the
        -- wound is still refreshing, and saying so every turn would turn the log into a drum.
        if want > have then
            ctx.log("action", string.format("%s works the same wound (%d).",
                (ctx.unit.char and ctx.unit.char.name) or "It", want))
        end
    end,
}
