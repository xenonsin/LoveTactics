-- PATIENT BLADE's rule (data/items/utility/utility_patient_blade.lua).
return {
    name = "Patient Blade",
    description = "+3 Damage on a turn after one you didn't move.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_patient", { magnitude = 0 })
    end,
}
