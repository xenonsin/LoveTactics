-- THE STRONGEST LEADS: the orc Warchief's rule, the elite's fight (data/items/utility/utility_warchiefs_presence.lua).
-- Approved as pitched (2026-09-26, "The Orcs of Wrath"); Keno made the Warchief the ELITE.
--
--   PRESENCE              allies within 3 of him deal +2 Damage (a presence, Trait.liveBonus)
--   THE STRONGEST LEADS   when he falls, the most-Proven orc on his side (ties: most health) takes his place: it
--                         heals half its health and takes up Presence and this rule (models/succession.lua)
--
-- Killing the head does not end the fight; it promotes the veteran. Kill him before anyone is Proven, or cut
-- the scarred ones down first.
return {
    name = "The Strongest Leads",
    description = "Allies within 3 deal 2 more damage. When it falls, the most-Proven orc takes its place, heals, and leads.",
    notAReaction = true,
    presence = { allies = true, radius = 3, damage = 2 },
    onDeath = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return end
        local Status = require("models.status")
        local Succession = require("models.succession")
        local heir = Succession.heir(combat, u, function(c)
            if not (c.char and c.char.race == "orc") then return -1 end
            return Status.stacksOf(c, "status_proven")
        end)
        if not (heir and heir.char and heir.char.race == "orc") then return end
        Succession.raise(combat, heir)
        local Trait = require("models.trait")
        heir.traits = heir.traits or {}
        heir.traits[#heir.traits + 1] = Trait.instantiate("trait_the_strongest_leads", nil)
        ctx.log("action", string.format("%s takes up the lead.", (heir.char and heir.char.name) or "Another"), heir)
    end,
}
