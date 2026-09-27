-- VITAE: the Blood-Ghoul's drop (Wrath's vampires, 2026-09-26). What a thrall is kept full of, in a stoppered vial.
-- Drink it: heal 60% of your max health and +3 Damage for three turns (status_vitae). Then you carry the Thirst for
-- three turns (status_borrowed_thirst): draw blood from a living body before it runs out, or spend one turn in
-- Bloodlust -- more damage, and the game takes your turn to bite whoever is nearest.
local SHARE = 0.60

return {
    name = "Vitae",
    description = "Heal 60% of your max health and increase damage by 3 for 3 turns. Then you carry the Thirst for 3 turns.",
    flavor = "A stoppered vial of dark blood, still warm through the glass.",
    sprite = "assets/items/consumable_vitae.png",
    type = "consumable",
    tags = { "restorative", "blood" },
    class = "alchemist",
    unlockLevel = 7,
    unstocked = true,
    maxStack = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        consumesItem = true,
        support = true,
        effect = function(fx)
            local user = fx.user
            local hp = user.char.stats.health
            fx.heal(user, math.max(1, math.floor((hp.max or 0) * SHARE + 0.5)))
            fx.applyStatus(user, "status_vitae")
        end,
    },
}
