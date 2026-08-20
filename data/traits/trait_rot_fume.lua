-- Rot-Fume: the standing rule of the Plague Knight's gauntlet. The bearer's blows land harder for every
-- poisoned body on the field.
--
-- This is rule R5, and it is the reason the Plague Knight is a discipline at all rather than a status
-- dispenser. Contagion spreads poison; poison ticks; and until this shipped, that was the entire loop --
-- the knight was manufacturing a condition that almost nothing in the catalog actually read. A mechanic
-- whose output nobody consumes is a mechanic that only looks like one.
--
-- Counted across the WHOLE FIELD rather than on the target, deliberately. A bonus keyed to "is this one
-- poisoned" would reward poisoning the thing you were about to hit, which is a worse plan than hitting
-- it twice. Counting everyone rewards the spread itself: the plague knight's damage is a readout of how
-- badly the fight is going for everyone else.
--
-- Runs through damageBonusVs, which is a PURE query fired on every damage preview -- so the number the
-- hover promises is the number the blow lands, and this must never mutate anything.
return {
    name = "Rot-Fume",
    description = "Increase damage by 3 per poisoned body on the field.",
    magnitude = 3, -- damage per poisoned body on the field
    damageBonusVs = function(ctx)
        local combat = ctx.combat
        if not combat then return 0 end
        local Status = require("models.status")
        local sick = 0
        for _, u in ipairs(combat.units or {}) do
            if u.alive and Status.has(u, "status_poison") then sick = sick + 1 end
        end
        return sick * (ctx.def.magnitude or 3)
    end,
}
