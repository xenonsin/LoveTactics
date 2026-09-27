-- A FAMILIAR ON ITS WAY BACK (the Familiar's Whistle, data/traits/trait_familiars_whistle.lua). The bat fell; at
-- the start of its caller's next turn it comes back beside them, reserving the Whistle's fifth of their mana again.
return {
    name = "Familiar Returning",
    abbr = "Bat",
    description = "Your familiar comes back beside you at the start of your next turn.",
    color = { 0.420, 0.300, 0.380 }, -- badge tint
    duration = 99,
    hideDuration = true,
    onTurnStart = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        local whistle = ctx.status.whistle
        ctx.expire()
        if not (u and u.alive and combat and whistle) then return end
        if whistle.activeSummon and whistle.activeSummon.alive then return end
        local Combat = require("models.combat")
        local x, y = Combat.openTileNear(combat, u.x, u.y)
        if not x then return end
        local bat = require("models.summon").spawn(combat, u, "character_familiar", x, y)
        if bat and bat.alive then
            whistle.activeSummon = bat
            local reserve = Combat.abilityReserve(u, whistle.activeAbility)
            if reserve and reserve.amount > 0 then Combat.reserve(u.char, reserve.stat, reserve.amount, bat) end
            ctx.log("action", string.format("%s's familiar comes back.", (u.char and u.char.name) or "Its"), u)
        end
    end,
}
