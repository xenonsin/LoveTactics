-- RUNS WITH THE PACK: the reading half of the pack aura.
--
-- Carried by every wolf in the game (grunt, alpha, the White Wolf herself), and worth exactly nothing
-- on a wolf standing alone. It looks outward for an ally carrying trait_pack_lead and, if one is in
-- reach, takes that lead's damage figure. Written from this side because Trait.liveBonus walks the
-- traits of the body whose stat is being read -- a passive can only raise the stats of its own bearer,
-- so every aura in this engine is "everyone looks for the leader" rather than "the leader reaches out".
-- data/traits/trait_pack_lead.lua is the other half and carries the two figures.
--
-- THE LARGEST LEAD APPLIES, NEVER THE SUM. The White Wolf's howl calls alphas onto a board she is
-- already standing on (ability_howl.lua), so a wolf inside two auras is the ordinary case here, not the
-- corner one. Summed, a fight's damage would come out of however many leads happened to be alive rather
-- than out of a number anybody chose; taking the best keeps the fight tunable from two authored figures
-- and keeps the badge honest -- a wolf is running with a lead, or it is not.
--
-- A LIVE PASSIVE, so it is re-read rather than banked: the buff appears the instant an alpha is called
-- and is gone the instant that alpha falls, with nothing to clean up and no status to strip. That is
-- the whole reason the kill order works -- every wolf on the board gets quieter as you clear the leads,
-- and the player can watch it happen in the damage numbers.
--
-- This runs inside every stat read on every hover frame, so it stays a bounded scan over the unit list
-- and allocates nothing. Trait.liveBonus pcalls it anyway (a bad data file must not blink the whole UI
-- out), which is a safety net and not a licence.
return {
    name = "Runs With The Pack",
    description = "Takes the damage bonus of the best pack leader in reach.",
    live = function(ctx)
        local combat = ctx.combat
        if not combat or not combat.units then return nil end
        -- Required here rather than at file scope: models/trait.lua loads this folder through the
        -- registry, so a top-level require would close a cycle at load time.
        local Combat = require("models.combat")
        local Trait = require("models.trait")
        local unit = ctx.unit
        local best = 0
        for _, other in ipairs(combat.units) do
            if other ~= unit and other.alive and other.side == unit.side then
                for _, t in ipairs(other.traits or {}) do
                    if t.id == "trait_pack_lead" then
                        local reach = Trait.param(t, "packReach", 2)
                        local amount = Trait.param(t, "packDamage", 3)
                        -- unitGap, not cellGap: a 2x2 lead carries from whichever of its corners is
                        -- nearest, the same measure reach is judged by everywhere else.
                        if amount > best and Combat.unitGap(unit, other) <= reach then
                            best = amount
                        end
                    end
                end
            end
        end
        if best <= 0 then return nil end
        return { damage = best }
    end,
}
