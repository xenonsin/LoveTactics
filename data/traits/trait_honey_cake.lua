-- HONEY-CAKE: a Cerberus head's own ("The Crown's Bestiary", slice C, approved 2026-10-09). "A Sleep, or a draught
-- thrown at a head, quiets that head for 2 turns." The Sibyl's honey-cake, which put the dog to sleep for Aeneas.
--
--   * a Sleep that lands on a head is set to two turns, whatever cast it (GatePit.quiet);
--   * a DRAUGHT is any consumable aimed at the head through the head picker (Combat.aimHead): the smallest reading of
--     "thrown at a head" this engine can say, since a flask is thrown at a tile and only a single-target piece can be
--     pointed at a head at all;
--   * and every wound the head takes is the body's too (GatePit.sync), so the body's bar is always the heads' sum.
--
-- A sleeping head does not bite (GatePit.awake), and a blow wakes it, as any blow wakes any sleeper.
local function GatePit() return require("models.gate_and_pit") end

return {
    name = "Honey-Cake",
    description = "A Sleep or a thrown draught quiets this head for 2 turns. Its wounds are the body's.",
    notAReaction = true, -- a sleeping head still bleeds into the body's bar
    onStatusApplied = function(ctx)
        if ctx.role == "recipient" and ctx.status and ctx.status.id == "status_sleep" then
            ctx.status.remaining = GatePit().QUIET_TICKS
        end
    end,
    onAnyCast = function(ctx)
        local head, item = ctx.unit, ctx.castItem
        if not (ctx.combat and ctx.combat.aimedHead == head and item and item.type == "consumable") then return end
        GatePit().quiet(ctx.combat, head)
    end,
    onDamaged = function(ctx)
        local body = ctx.unit and ctx.unit.headOf
        if body then GatePit().sync(ctx.combat, body) end
    end,
}
