-- THE RETAINER'S OATH: the Elf Retainer's rule (data/characters/character_elf_retainer.lua; the creature identity pass,
-- 2026-11-19). Beside an Unblemished elf, it takes every blow meant for that elf. The work is in models/elf_court.lua:
-- the oath is a declared Oathward that holds only while its charge is still Unblemished, re-sworn at the bell and at
-- every turn's edge, because any of those can have moved the retainer, its charge, or the blow that marked it.
local function Court() return require("models.elf_court") end

return {
    name = "Retainer's Oath",
    description = "Takes every blow meant for an Unblemished elf beside it.",
    retainsTheCourt = true,
    grade = 0.0, -- a body's own organ, never shelved (models/grade.lua weighs it here, beside the rule)
    onCombatStart = function(ctx) Court().swear(ctx.combat, ctx.unit) end,
    onTurnStart = function(ctx) Court().swear(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) Court().swear(ctx.combat, ctx.unit) end,
    onAnyTurnStart = function(ctx) Court().swear(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx) Court().swear(ctx.combat, ctx.unit) end,
    onAnyDeath = function(ctx) Court().swear(ctx.combat, ctx.unit) end,
    -- A fallen retainer covers nobody: drop the oath and lift the badge off the elf it stood beside.
    onDeath = function(ctx)
        ctx.unit.guard = nil
        Court().badges(ctx.combat)
    end,
}
