-- WOUNDED PRIDE: the elf court's second rule (models/elf_court.lua; the creature identity pass, 2026-11-19). The blow
-- that marks a court elf -- the one that takes its Unblemished away -- Taunts it onto whoever struck it, for two turns.
--
-- Heard on onDamaged, which Combat runs BEFORE the statuses hear the same blow, so Unblemished is still on the body
-- when this asks; the status's own hook takes it off right after. A blow with no striker (a burn, a trap) compels
-- nothing.
local function Court() return require("models.elf_court") end

return {
    name = "Wounded Pride",
    description = "The blow that ends its Unblemished Taunts it onto the striker for 2 turns.",
    tauntTicks = 10, -- two turns at Status.TICKS_PER_TURN
    grade = 0.0, -- a body's own organ, never shelved (models/grade.lua weighs it here, beside the rule)
    onDamaged = function(ctx)
        Court().affronted(ctx.combat, ctx.unit, ctx.attacker, ctx.amount, ctx.trait)
    end,
}
