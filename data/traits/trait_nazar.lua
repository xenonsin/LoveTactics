-- NAZAR: the Evil Eye's trophy rule (data/items/utility/utility_nazar.lua), on an Exorcist. Reviewed 2026-10-01..03
-- ("Envy's Bestiary", round 1). The charm against the eye: the first debuff or curse that would land on the
-- bearer each fight is turned aside.
--
-- One latch for both (models/envy_oneoffs.lua's turnAside). A HEX is refused before it takes a piece
-- (Combat.curseItem asks); a DEBUFF is lifted the moment it lands, the Cleansing Ward's way -- so a debuff's
-- landing beat (a Stun's shove down the order) has already happened by the time the charm answers.
return {
    name = "Nazar",
    description = "The first debuff or curse that would land on you each fight is turned aside.",
    turnsAside = true,
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" then return end
        local landed = ctx.status and ctx.status.def
        if not (landed and landed.debuff) then return end
        if require("models.envy_oneoffs").turnAside(ctx.combat, ctx.unit, landed.name) then
            ctx.clearStatus(ctx.unit, ctx.status.id)
        end
    end,
}
