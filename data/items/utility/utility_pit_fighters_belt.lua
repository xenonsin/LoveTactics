-- THE PIT-FIGHTER'S BELT: the Pit-Fighter's drop (approved as pitched, 2026-09-26, "The Orcs of Wrath"). The
-- Challenge turned round: take half damage from every foe except the one you last struck (trait_pit_fighters_belt,
-- status_single_combat). For the body that picks one fight and stays in it; it holds nobody in place.
return {
    name = "Pit-Fighter's Belt",
    description = "Take half damage from every foe except the one you last struck.",
    flavor = "Wide as a hand and notched for every bout. Somebody stopped counting, or stopped being able to.",
    sprite = "assets/items/utility_pit_fighters_belt.png",
    type = "utility",
    tags = { "trinket" },
    class = "champion",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_pit_fighters_belt" },
}
