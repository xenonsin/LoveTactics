-- LIVING ROCK: what an Earth Golem IS (reviewed 2026-09-25, "The Golems of Greed"). The mountain's own
-- rock, stood up -- nobody built it -- and its two rules ride here, the way a dwarf's ride Stout:
--   * SHED PLATE    three slabs, +2 Defense each; an impact blow knocks one off into a rubble wall
--                   (trait_shed_plate, status_stone_plate)
--   * THE VEIN      the hole it Delves out of is a coin heap, or one time in three a lava pit
--                   (trait_strikes_vein; the Delve itself is the Delver's own ability_delve)
--
-- BOUND AND UNSTEALABLE: an organ, not kit. Nothing comes off a corpse here.
return {
    name = "Living Rock",
    description = "Stone plates an impact blow knocks off as rubble. Where it delves, it leaves gold or lava.",
    flavor = "It was a wall of the mine until something in the gold woke it.",
    sprite = "assets/items/utility_living_rock.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_shed_plate", "trait_strikes_vein" },
    traitParams = { plateStatus = "status_stone_plate", plates = 3, shedAs = "rubble" },
}
