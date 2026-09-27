-- IRON MAIDEN: the Blood Countess's second drop (data/items/armor/armor_iron_maiden.lua). Any foe that hits the
-- wearer in melee Bleeds, and the wound is the WEARER's (`applier`), so a vampire in it drinks what the attacker
-- spills walking away. Spiteful Ichor's shape (trait_spiteful_ichor): free, uncooled, answers an answer.
return {
    name = "Iron Maiden",
    description = "Melee attackers Bleed.",
    counter = { reach = "melee", requiresTag = "physical", answersReactions = true,
                applies = "status_bleed" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        ctx.applyStatus(ctx.attacker, "status_bleed", { applier = ctx.unit })
        ctx.log("action", string.format("%s is cut on the spikes.",
            (ctx.attacker.char and ctx.attacker.char.name) or "The attacker"))
    end,
}
