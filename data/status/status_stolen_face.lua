-- STOLEN FACE: the timer that owns a face worn for a while (models/stolen_faces.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary", round 2). Three things put one on, and it is one word for all of them: the Skin-Thief's
-- flaying (2 turns, and the flayed body is Halted for the same 2), Borrowed Face (3 turns) and Hall of Faces
-- (2 turns). Whoever wears it IS that body -- its stats and kit -- on its own health pool (the transform rule).
--
-- The shape is put on by whatever applies this, and this owns taking it off: onExpire fires on every removal
-- path, so a countdown, a dispel and the wearer's death all end it the same way. When the Skin-Thief's face
-- comes off, the body it flayed gets its face back (its Halt lifts).
--
-- Not a debuff -- it is something the wearer did -- and an illusion, like every worn shape, so Dispel Illusions
-- tears it off.
return {
    name = "Stolen Face",
    abbr = "SFce",
    description = "Stolen Face: wearing another body's face, its stats and kit. Health stays its own.",
    color = { 0.760, 0.560, 0.520 }, -- badge tint (raw skin)
    duration = 10,
    illusion = true,
    onExpire = function(ctx)
        require("models.stolen_faces").takeOff(ctx.combat, ctx.unit, ctx.status)
    end,
    onDeath = function(ctx)
        ctx.expire()
    end,
}
