-- ALREADY KNOWN: the spells a body has seen cast this fight (data/traits/trait_already_known.lua -- Sublimitas,
-- and the Codex Unanswered lifted off her). The record IS this status: Trait.learnSpell writes each spell into
-- `known` (by id) and `order` (by name, as learned), and Trait.knowsSpell reads it back, so the badge and the
-- rule are one table. The badge prints the count (`badgeCount`); the tooltip lists the spells.
--
-- Not a debuff, so no Cure lifts it -- and there is nothing to cure: knowing a thing is not an affliction.
local BASE = "Spells seen cast this fight. Aimed at this body, a Known spell is unravelled."

return {
    name = "Already Known",
    abbr = "Know",
    description = BASE,
    color = { 0.620, 0.560, 0.860 }, -- badge tint (a page's violet ink)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    badgeCount = true,
    magnitude = 0,
    -- The live list, for ui/status_tooltip.lua. A log line's snapshot carries no `order` and reads the base.
    describe = function(status)
        local order = status and status.order
        if not order or #order == 0 then return BASE end
        return BASE .. " Known: " .. table.concat(order, ", ") .. "."
    end,
}
