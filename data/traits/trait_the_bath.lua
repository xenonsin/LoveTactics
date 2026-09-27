-- THE BATH: the Blood Countess's rule (models/basin.lua). When a Blood Basin on her side is full she bathes at the
-- top of her next turn, from wherever she stands: healed to full, +2 Speed and +20% Damage, to two baths.
return {
    name = "The Bath",
    description = "When the basin is full, bathe next turn: heal to full, +2 Speed and +20% Damage. Stacks to two.",
    bathes = true,
    notAReaction = true,
}
