-- Rampart Buckle: every time the bearer is hit, each SHIELD sitting next to the buckle in the grid raises
-- barrier (3, by the buckle's forge). Getting hit builds the engine; where the shields sit decides how
-- fast. The knight's Rampart grid piece.
return {
    name = "Rampart Buckle",
    description = "When you are hit, each shield next to it grants 3 barrier.",
    magnitude = 3,
    notAReaction = true, -- the buckle is a strap, not a reflex: a stunned knight still has it on
    onDamaged = function(ctx)
        local buckle = ctx.trait.item
        local char = ctx.unit.char
        if not (buckle and char and ctx.unit.alive) then return end
        local Character = require("models.character")
        local idx = Character.slotIndex(char, buckle)
        if not idx then return end
        local shields = 0
        for _, nb in ipairs(Character.adjacentItems(char, idx)) do
            for _, t in ipairs(nb.tags or {}) do
                if t == "shield" then shields = shields + 1 break end
            end
        end
        if shields <= 0 then return end
        local per = ctx.param("barrier", ctx.def.magnitude or 3)
        require("models.engine").grantBarrier(ctx.combat, ctx.unit, shields * per)
    end,
}
