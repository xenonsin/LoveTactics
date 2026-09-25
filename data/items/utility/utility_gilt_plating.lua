-- GILT PLATING: the Gold Golem's drop (round 2, "The Golems of Greed"). The golem's gold plates on the
-- company's side: two plates, +2 Defense each, and an impact blow knocks one off as a coin heap on the
-- clear tile beside you. Walk back over it and the plate goes on again -- the gold is the plate's, not
-- the purse's (trait_shed_plate "reclaim", hazard_coin_heap's `plateOf`). A companion who loots it
-- banks it as gold and the plate is gone; a dwarf pockets it; a Gold Golem eats it.
--
-- Beside Shale Plating on purpose and flagged as close to it on the review: that one trades armour for
-- cover, this one for a plate you can go and take back.
return {
    name = "Gilt Plating",
    description = "Two gilt plates (+2 Defense each). An impact blow knocks one off as a coin heap; step on it to wear it again.",
    flavor = "Thin enough to fall off. Valuable enough that you go back for it.",
    sprite = "assets/items/utility_gilt_plating.png",
    type = "utility",
    tags = { "trinket" },
    class = "mammonite",
    unlockLevel = 5,
    traits = { "trait_shed_plate" },
    traitParams = { plateStatus = "status_gilt_plate", plates = 2, shedAs = "reclaim" },
}
