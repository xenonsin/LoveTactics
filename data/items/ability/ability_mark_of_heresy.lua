-- Mark of Heresy: the Inquisitor names a foe apostate, and the naming is the weapon. Applies Mark
-- (data/status/status_mark.lua -- defense and magic defense cut), softening the target for the whole
-- party and, in the Inquisitor's hand (rogue x priest), arming the killing judgment. No damage of its
-- own: it is setup, said in a censer's voice rather than a bowstring's. Costs mana, as the faithful do.
return {
    name = "Mark of Heresy",
    description = "Brands a foe a heretic: its defense and magic defense drop, marking it for judgment.",
    flavor = "The verdict comes later. The Mark is only the reading of the charge.",
    sprite = "assets/items/ability_mark_of_heresy.png",
    type = "ability",
    tags = { "utility", "holy" },
    class = "priest",
    discipline = "inquisitor", -- rogue x priest; the Judgment mechanic's first stock
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 5 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_mark")
        end,
    },
}
