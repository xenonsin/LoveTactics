-- BARBED FLETCHING: every weapon blow its bearer lands leaves a quill in the foe it struck
-- (status_quilled). The manticore's volley rebuilt for a person, and asked for in so many words on review
-- (2026-09-23): "utility that applies quill on each attack" -- one foe at a time, but on every swing.
--
-- A BLOW THAT MISSED LEAVES NOTHING. `onCast` fires on a thrown swing as readily as a landed one, so it
-- is gated on the cast having drawn blood -- trait_fury_swipes' rule, for trait_fury_swipes' reason.
-- Weapons only: an ability is its own decision about what it inflicts, and a charm that rode every spell
-- as well would be a second Quillhide on the offence.
return {
    name = "Barbed Fletching",
    description = "Your weapon blows inflict Quilled on the foe they strike.",
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        if not (ctx.item and ctx.item.type == "weapon") then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not (target and target.alive) or target.side == ctx.unit.side then return end
        ctx.applyStatus(target, "status_quilled")
    end,
}
