-- A weapon somebody threw (data/items/ability/ability_toss.lua), lying where it landed. The thrower walks over
-- it to take it back: its grid cell is refused (Combat.itemBlockReason, `tossed`) until then. Nobody else can
-- pick it up -- it is not loot, it is a thing on its way home.
--
-- It never outlasts the fight in any way that matters: the mark lives on the unit, so the fight's end returns
-- the weapon by ending. The duration is only the ceiling a hazard must have -- and when it runs out the
-- weapon is handed back all the same (onExpire), so a pile cannot strand a blade for the rest of a long fight.
local function giveBack(h)
    local thrower, item = h.thrower, h.item
    if thrower and thrower.tossed and item then thrower.tossed[item] = nil end
end

return {
    name = "Thrown Weapon",
    description = "A thrown weapon. Its thrower takes it back by walking over it.",
    tags = { "object" },
    duration = 100, -- twenty turns; it is handed back when this runs out too
    disposition = "neutral",
    onEnter = function(ctx)
        local h = ctx.hazard
        if not (h and h.alive and ctx.unit and ctx.unit == h.thrower) then return end
        giveBack(h)
        require("models.hazard").consume(ctx.combat, h)
        require("models.combat").logEvent(ctx.combat, "action", string.format("%s picks its weapon back up.",
            (ctx.unit.char and ctx.unit.char.name) or "Something"), ctx.unit)
    end,
    onExpire = function(ctx) giveBack(ctx.hazard or {}) end,
}
