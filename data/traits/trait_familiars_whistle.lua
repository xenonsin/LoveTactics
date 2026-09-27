-- THE FAMILIAR'S WHISTLE: the Familiar's drop (data/items/ability/ability_familiars_whistle.lua). The familiar it
-- calls comes back: when it falls, it returns beside its caller at the start of the caller's next turn
-- (status_familiar_returning), reserving the Whistle's fifth of their mana again.
return {
    name = "Familiar's Whistle",
    description = "If your familiar falls, it comes back beside you at the start of your next turn.",
    onSummonLost = function(ctx)
        local u, lost = ctx.unit, ctx.lost
        if not (u and u.alive and lost and lost.char and lost.char.id == "character_familiar") then return end
        if not (ctx.item and ctx.item.activeSummon == lost) then return end
        local st = ctx.applyStatus(u, "status_familiar_returning")
        if st then st.whistle = ctx.item end
    end,
}
