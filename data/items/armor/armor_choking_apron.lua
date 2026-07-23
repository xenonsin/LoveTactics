-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Choking Fumes that walk (`incense`, Combat.layIncense): foes standing in the square around the
-- wearer are Poisoned, and the party breathes freely -- hazard_choking is SIDED to the bearer.
--
-- The Rimeguard's chemical opposite number, and the pair is worth reading together. That coat denies
-- the ground by making it slow, which an enemy answers by not being there; this denies it by making it
-- expensive to stand in, which an enemy answers by taking the poison and killing you anyway. Neither
-- is strictly better -- what separates them is what the wearer's party does with the tile: a knight
-- wants the enemy stalled, an alchemist wants them afflicted, because half the Crucible's catalog is
-- priced on how afflicted the target already is.
--
-- The apron therefore does its real work through OTHER items. On its own it is a slow tick. In a grid
-- with anything that spoils the poisoned, it is a walking setup that costs no action.
--
-- Note the wearer must be adjacent to the enemy line for any of it to matter, which is an
-- uncomfortable place for the party's alchemist to be, and is the item's whole price.
return {
    name = "Choking Apron",
    description = "Carries poisoned smoke with you: foes standing in it are Poisoned, allies are not.",
    flavor = "The Crucible's benches are ventilated. The aprons were the cheaper half of the solution.",
    sprite = "assets/items/armor_choking_apron.png",
    type = "armor",
    tags = { "leather", "poison" },
    class = "alchemist",
    incense = { hazard = "hazard_choking", radius = 1 },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
    resist = { poison = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 } },
}
