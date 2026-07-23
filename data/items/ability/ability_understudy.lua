-- The Understudy: Final Fantasy Tactics' Mime, which had no abilities of its own and repeated whatever
-- an ally had just done. Renamed because "mime" says pantomime, and this is the other word for the same
-- idea -- the one who learns another's part by watching it, stands ready every night, and performs
-- nothing that was written for them.
--
-- It repeats the last PHYSICAL action your side committed (Combat.lastPhysical, recorded at the end of
-- resolveCast), aimed wherever you like. Not the action it was aimed at then -- the motion, re-thrown.
-- The swordsman cleaves and then the alchemist cleaves, with the swordsman's sword, at something else.
--
-- WHY PHYSICAL ONLY, and it is the load-bearing restriction rather than a balance tweak. Pride already
-- owns the magical version of this: Perfect Recall (data/traits/trait_perfect_recall.lua) is the
-- Unequalled having "only to glance at a working to own it" -- she sees a spell and it is hers. If the
-- Understudy copied spells it would be a worse, purchasable retelling of a general's defining rule, and
-- the two sins would be saying the same sentence. So the line is drawn where the sins actually differ:
--   * PRIDE takes the WORKING. It is about intellect, it is about spells, and it is theft by
--     comprehension -- she understands it faster than you cast it.
--   * ENVY takes the MOTION. It is about the body, it never understands anything, and it is theft by
--     imitation -- it watched your hands and it can do that now, without ever knowing why it works.
-- An understudy who could improvise would not be an understudy. Envy copies what it saw; it does not
-- get to copy what you knew.
--
-- Read beside the shelf's other two borrowings and the alchemist's whole thesis is visible:
-- Summon Golem buys somebody else's courage, Throw Item throws somebody else's chemistry, and this
-- performs somebody else's training. Three items, no power of its own in any of them.
--
-- THE TOOLTIP TELLS THE TRUTH, which took the one piece of machinery in this file. An ability whose
-- effect changes every turn cannot describe itself with a fixed sentence, so the item RELABELS its own
-- instance to name whatever it is currently holding -- see relabel() below. Items are per-character
-- mutable copies of their blueprints (models/item.lua), so writing to the instance is exactly as
-- legitimate as an upgrade level is, and the blueprint is untouched.
local IDLE_NAME = "Understudy"
local IDLE_DESC = "Repeats the last physical action your side took. Nothing rehearsed yet."

-- What this Understudy would repeat right now: the last physical action recorded for the caster's own
-- side (`unit.lastPhysical`, stamped at the end of resolveCast), or nil. A pure read of the unit, which
-- is what `usable` is required to be.
--
-- Never the Understudy itself -- an understudy rehearsing an understudy is a loop with nothing at the
-- bottom of it, and it would let one cast echo off its own recording forever.
local function rehearsed(unit, item)
    local last = unit and unit.lastPhysical
    if not last or last == item then return nil end
    return last
end

-- Rewrite this instance's own name and description to name what it is holding, so the grid slot, the
-- tooltip and the hover text all read the truth rather than a generic promise. Called from `usable`,
-- which the UI already asks every frame it draws a slot (Combat.itemBlockReason) -- a side effect in a
-- predicate is not lovely, but the alternative is a UI that supports function-valued labels for the
-- sake of exactly one item, and this keeps the machinery inside the file that needs it.
local function relabel(item, copied)
    if copied then
        item.name = "Understudy: " .. (copied.name or "?")
        item.description = string.format("Repeats %s, aimed wherever you choose.", copied.name or "the last motion")
    else
        item.name = IDLE_NAME
        item.description = IDLE_DESC
    end
end

return {
    name = IDLE_NAME,
    description = IDLE_DESC,
    flavor = "It watched your hands. It cannot tell you why that works, and it can do it now.",
    sprite = "assets/items/ability_understudy.png",
    type = "ability",
    tags = { "physical" },
    class = "alchemist",
    price = 400,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4, -- its own tempo, not the copied motion's: a rehearsal is never as quick as the thing
        cost = { stat = "stamina", amount = 5 },
        usable = function(unit, item)
            local copied = rehearsed(unit, item)
            relabel(item, copied) -- the tooltip names what is actually in hand right now
            if copied then return true end
            return false, "nothing rehearsed yet"
        end,
        effect = function(fx)
            local copied = rehearsed(fx.user, fx.item)
            if not copied then return end -- `usable` gates this; stay safe on a direct call
            fx.log("action", string.format("%s repeats %s.",
                fx.user.char.name or "The understudy", copied.name or "the motion"), fx.user)
            -- The copied item's OWN effect, at the copied item's own level and with its own riders --
            -- a borrowed sword still bleeds, a borrowed axe still cleaves. It pays none of that item's
            -- cost: the Understudy already paid its own, which is the trade (a cheap arm, a strong
            -- motion), and billing both would make copying a greatsword strictly worse than owning one.
            fx.strikeWith(copied)
        end,
    },
}
