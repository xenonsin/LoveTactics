-- SUCCESSION: the rider on The Strongest Leads, the Warchief's second drop
-- (data/items/ability/ability_the_strongest_leads.lua). Keno's round-1 note: "a separate ability that transfers
-- this buff to the next living just like the orc chief". Once the ability has been cast (status_succession), the
-- bearer's fall passes every boon it holds to the living ally with the most health, who heals half its health
-- (models/succession.lua). Cast ahead of time, because a body that is down cannot act.
return {
    name = "Succession",
    description = "Once cast, if you fall this fight, your boons pass to the ally with the most health, who heals half.",
    notAReaction = true,
    onDeath = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return end
        local Status = require("models.status")
        if not Status.has(u, "status_succession") then return end
        local Succession = require("models.succession")
        local heir = Succession.heir(combat, u)
        if not heir then return end
        Succession.passBoons(combat, u, heir)
        Succession.raise(combat, heir)
        Status.remove(combat, u, "status_succession")
        ctx.log("action", string.format("%s takes up the lead.", (heir.char and heir.char.name) or "An ally"), heir)
    end,
}
