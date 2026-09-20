-- ADAPTIVE: whatever hurt it last cannot hurt it again, and is what it hits you with.
--
-- The rule a slime is built around (data/characters/character_slime.lua, and the King above it). Its
-- body answers steel by not being made of anything steel can part -- that half is the `immune` table
-- on data/items/utility/utility_amorphous_body.lua, armour rather than a reaction, and it is not this
-- file's. This file is the other half: what the body DOES about the things that can still reach it.
--
-- Two effects, one idea, which is why they are one trait and not two:
--
--   * onDamaged  -- an elemental blow lands, and the body takes that element into itself: it gains
--                   Immune: <element>, the same status the Arcanum's Seal grants an ally, and sheds
--                   whichever one it was wearing before.
--   * carriesWardedElement -- a standing flag Combat.strikeElement reads. Its blows carry whatever it
--                   is currently proof against, off the immunity itself rather than off a second
--                   field beside it, so the two halves can never disagree about which element it is
--                   wearing. What it will not take, it gives.
--
-- ONE ELEMENT AT A TIME, AND THAT IS THE WHOLE COUNTERPLAY. The old adaptation is stripped before the
-- new one lands, so a party with two elements always has an answer and a party with one has exactly
-- one blow: the first fire lands, and every fire after it is voided until somebody throws something
-- else. Stacking them instead would mean a body that becomes unkillable in the exact number of turns
-- it takes to show the player all of its tricks, which is a puzzle with no solution rather than a
-- hard one.
--
-- IT CANNOT ADAPT TO WHAT IT ALREADY SHRUGS OFF, and it never has to: Combat.dealFlatDamage returns a
-- true 0 on an immune hit BEFORE the trait dispatch, so a second Fireball into a fire-proof slime
-- fires no hook at all. The same short-circuit is why the physical immunity never teaches it anything
-- -- a sword is not an experience it has.
--
-- THE ADAPTATION IS A WINDOW, not a permanent state, and the duration below is the fight's rhythm. A
-- long grind outlasts it; the swing after it lapses lands. Held as a tunable (Trait.param) so a
-- deeper body can buy a longer memory without a second blueprint -- the King's is the same rule at
-- the same length, because the thing that makes a King hard is the bodies inside it, not a better
-- memory.
return {
    name = "Adaptive",
    description = "Takes an element into itself: proof against it, and striking with it.",
    -- ~8 turns at the usual five-or-so ticks a turn: long enough that re-throwing the element you
    -- just fed it is a wasted turn rather than a near miss, short enough that a fight can outlast it.
    duration = 40,
    carriesWardedElement = true,
    onDamaged = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive) then return end
        local Combat = require("models.combat")

        -- The blow's own tag order, which is authored and so replays identically. A blow carrying two
        -- elements feeds it the one its author wrote first, which is the one the weapon is about.
        local element
        for _, t in ipairs(ctx.tags or {}) do
            if Combat.ELEMENT_TAGS[t] then element = t; break end
        end
        if not element then return end

        -- Shed the previous adaptation first. Only the ELEMENTS are swept: a Seal: Slash somebody cast
        -- on this body is a different promise and is none of this rule's business.
        for _, e in ipairs(Combat.ELEMENTS) do
            if e ~= element then ctx.clearStatus(unit, "status_immune_" .. e) end
        end
        ctx.applyStatus(unit, "status_immune_" .. element, { duration = ctx.param("duration", 40) })

        -- Named with the element's own word, the same one the badge carries (Immune: Fire), so the
        -- line in the log and the mark on the token are plainly the same fact.
        ctx.log("status", string.format("%s adapts to %s.",
            (unit.char and unit.char.name) or "It", element:sub(1, 1):upper() .. element:sub(2)), unit)
    end,
}
