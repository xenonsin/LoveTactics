-- THREE HEADS: the Vanguard's drop off Cerberus ("The Crown's Bestiary", slice C; data/items/ability/
-- ability_three_heads.lua). "Range 0. This turn, your attack strikes up to three different adjacent foes."
--
-- The ability puts the badge on (status_three_heads) and costs no tempo; this, on the bearer's own onCast, is the
-- blow it buys: a melee weapon swung while the badge is worn strikes up to two more foes beside the bearer with the
-- same weapon (Combat.strikeWith, which Dual Wield swings through), and spends the badge. Each extra head is its own
-- blow, rolled and mitigated on its own.
return {
    name = "Three Heads",
    description = "While Three Heads is worn, your next melee blow strikes up to two more foes beside you.",
    onCast = function(ctx)
        require("models.gate_and_pit").extraHeads(ctx.combat, ctx.unit, ctx.item, ctx.tx, ctx.ty)
    end,
}
