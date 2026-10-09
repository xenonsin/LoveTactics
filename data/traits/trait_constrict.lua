-- CONSTRICT: the naga plague knight's race item (data/items/utility/utility_constrict.lua, "The Rift's
-- Adventurers", slice D). A blow the bearer lands on a Poisoned foe that is still standing Roots it. On the
-- striker's side of the blow (Trait.onBlowLanded), so a Poison tick, which has no striker, roots nothing.
return {
    name = "Constrict",
    description = "Your blows Root a foe that is Poisoned.",
    onBlowLanded = function(ctx)
        local t = ctx.target
        if t and t.alive and require("models.status").has(t, "status_poison") then
            ctx.applyStatus(t, "status_root", { applier = ctx.unit })
        end
    end,
}
