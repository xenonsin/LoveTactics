-- THREE UTTERANCES: the Brazen Head's (data/items/utility/utility_brazen_voice.lua; "Envy's Bestiary", 2026-10-03,
-- slice C). Friar Bacon's head speaks three times, in order, and each utterance is a wind-up a shove breaks
-- (Combat.interruptChannel). The order is kept on the head (`unit.utterances`, models/envy_seat.lua): only the
-- utterance it is due is usable, and one that was broken is tried again.
--
-- The count moves and the ledger is written here, on the real cast's onCast, never inside an utterance's effect:
-- an effect is also run as a dry-run preview, and a preview must not advance the head.
--
-- The ledger is what Time Was reads: every body on the head's side and the health it stood at when the head last
-- spoke (or when the bell rang).
local EnvySeat = function() return require("models.envy_seat") end

return {
    name = "Three Utterances",
    description = "Speaks Time Is, Time Was and Time Is Past, in order. Each is a wind-up a shove breaks.",
    brazenHead = true,
    notAReaction = true,
    onCombatStart = function(ctx)
        EnvySeat().markTime(ctx.combat, ctx.unit)
    end,
    onCast = function(ctx)
        local u, item = ctx.unit, ctx.item
        if not (u and item) then return end
        for _, id in ipairs(EnvySeat().UTTERANCES) do
            if item.id == id then
                u.utterances = EnvySeat().spoken(u) + 1
                EnvySeat().markTime(ctx.combat, u)
                return
            end
        end
    end,
}
