-- TWO HEADS: the Hydra's regrowth worn as a coat (data/items/armor/armor_two_heads.lua, models/lerna.lua). Each
-- slash blow that strikes the wearer banks one more strike on its next weapon attack (status_two_heads, up to 3).
-- A reaction like any other: a stunned wearer grows nothing.
return {
    name = "Two Heads",
    description = "Each time a slash blow strikes you, your next attack strikes one more time (up to 3).",
    onDamaged = function(ctx)
        require("models.lerna").growHead(ctx.combat, ctx.unit, ctx.tags)
    end,
}
