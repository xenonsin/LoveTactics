-- SPIRIT BODY, the Archons' race (data/races/archon.lua). The bearer falls, and its spirit is thrown clear as a
-- wisp (models/spirit.lua does the placing and the walking home).
--
-- ONCE, on the body rather than on the trait: `spiritSpent` is stamped on the unit when the wisp is thrown, and a
-- raise wipes a body's statuses but not its fields, so the stamp survives the standing-up and the second fall is
-- final. The author's "a wisp returns only once" is the whole of why this is a field and not a stack.
--
-- A WISP IS ITSELF AN ARCHON (it wears the race), so the guard on `summoned` is what keeps a wisp's own death
-- from throwing another wisp.
return {
    name = "Spirit Body",
    description = "When felled, a wisp tears loose and walks back to the body. If it arrives, the body stands at half.",
    onDeath = function(ctx)
        require("models.spirit").release(ctx.combat, ctx.unit)
    end,
    -- THE CROWN'S BESTIARY, SLICE A (2026-10-09): an Archon struck and still standing is what a Greater Archon's
    -- ward answers (models/archon_court.lua). Heard here because every Archon carries this trait and no hook
    -- broadcasts a wound to the bodies around it.
    onDamaged = function(ctx)
        require("models.archon_court").struck(ctx.combat, ctx.unit)
    end,
}
