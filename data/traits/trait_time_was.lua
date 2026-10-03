-- TIME WAS: the record the Theurge's Time Was reads (data/items/ability/ability_time_was.lua; "Envy's Bestiary",
-- 2026-10-03, slice C, the Brazen Head's drop). At the top of each of the bearer's turns it writes down where every
-- ally stands, and keeps the one before: the cast returns an ally to the health it had at the start of the
-- bearer's LAST turn, which is the round of blows it has taken since.
--
-- Written on the bearer's own turn start (Trait.onAnyTurnStart's own-turn dispatch) and at the bell, so a cast on
-- the first turn reads the opening line. Kept on the unit (`timeWas`), never in the ability's effect, which a
-- preview also runs.
local function mark(ctx)
    local u = ctx.unit
    local now = {}
    for _, ally in ipairs(ctx.combat.units or {}) do
        if ally.alive and ally.side == u.side then now[ally] = ally.char.stats.health.current end
    end
    u.timeWas = { last = (u.timeWas and u.timeWas.now) or now, now = now }
end

return {
    name = "Time Was",
    description = "Remembers where each ally stood at the start of your last turn.",
    notAReaction = true,
    onCombatStart = mark,
    onTurnStart = mark,
}
