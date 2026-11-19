-- THE STRONGEST LEADS: the orc Warchief's rule, the elite's fight (data/items/utility/utility_warchiefs_presence.lua).
-- Approved as pitched (2026-09-26, "The Orcs of Wrath"); Keno made the Warchief the ELITE.
--
--   PRESENCE              a foe that ends its turn beside him is Rooted: it does not walk away from him
--   THE STRONGEST LEADS   when he falls, the most-Proven orc on his side (ties: most health) takes his place: it
--                         heals half its health and takes up Presence and this rule (models/succession.lua)
--
-- Killing the head does not end the fight; it promotes the veteran. Kill him before anyone is Proven, or cut
-- the scarred ones down first.
--
-- PRESENCE WAS A PACK AURA UNTIL 2026-11-19 (the creature identity pass): allies within 3 dealt +2 Damage. The
-- audit found every Wrath race fielding a kill-the-head alpha behind a pack aura -- the Oni General, the
-- Hobgoblin, this one -- and asked for about half of them to pull a different lever. His is POSITION now: whoever
-- steps up to him and stays is held there for its next turn, so a company engages him with the body that can
-- stand and trade, and reaches him from two tiles out with everything else. Rooted is a debuff, so a Cure frees
-- the held body; that is the tool it asks for.
return {
    name = "The Strongest Leads",
    description = "A foe that ends its turn beside it is Rooted. When it falls, the most-Proven orc takes its place, heals, and leads.",
    notAReaction = true,
    onAnyTurnEnd = function(ctx)
        local u, combat, actor = ctx.unit, ctx.combat, ctx.actor
        if not (u and u.alive and combat and actor and actor.alive and actor.side ~= u.side) then return end
        local Combat = require("models.combat")
        if Combat.isOffTile(actor) or Combat.unitGap(u, actor) > 1 then return end
        local Status = require("models.status")
        if Status.has(actor, "status_root") then return end
        ctx.applyStatus(actor, "status_root", { applier = u })
        ctx.log("action", string.format("%s holds %s where it stands.", (u.char and u.char.name) or "The Warchief",
            (actor.char and actor.char.name) or "it"), actor)
    end,
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
