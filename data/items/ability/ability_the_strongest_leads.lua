-- THE STRONGEST LEADS: the orc Warchief's second drop, round 2 (2026-09-26, "The Orcs of Wrath"), on Keno's note:
-- "a separate ability that transfers this buff to the next living just like the orc chief." Cast it and, for the
-- rest of the fight, if you fall, every boon you hold -- Taken Up, Proven, Unbroken, any buff -- passes to the
-- living ally with the most health, who heals half its health (status_succession, trait_succession,
-- models/succession.lua). Cast ahead of time, because a body that is down cannot act. The partner of the Heir's
-- Torc: the Torc grows when another falls, this keeps what it built when you do.
return {
    name = "The Strongest Leads",
    description = "Once this fight, if you fall, your boons pass to the ally with the most health, who heals 50%.",
    flavor = "Not a will. A will asks. This only tells them who is next.",
    sprite = "assets/items/ability_the_strongest_leads.png",
    type = "ability",
    tags = { "command" },
    class = "warlord",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_succession" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        cooldown = 999, -- once a fight
        support = true,
        cost = { stat = "stamina", amount = 4 },
        effect = function(fx)
            if fx.user then fx.applyStatus(fx.user, "status_succession") end
        end,
    },
}
