-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- The first time the wearer drops below 40% health, the plate raises a barrier and gives them +4
-- damage for the rest of the battle (trait_last_stand). Once, and then never again.
--
-- Wrath's own bargain in a single trigger: the thing that nearly killed you is the thing that arms
-- you. Note the order it pays in -- the barrier buys the turn, the damage spends it -- so what the
-- plate actually hands over is one more swing than the wearer had, at the exact moment swings ran out.
--
-- The 40% line is what makes it a decision rather than a passive. A fighter who plays carefully never
-- collects, which means the correct way to wear this is to stop playing carefully, and that is the sin
-- doing its job through a stat block. Compare armor_mail_of_the_unappeased, which pays continuously
-- the nearer death you are: Ira's mail wants you to LIVE there, this wants you to arrive there once
-- and win before you arrive twice.
--
-- Heavy, so two squares of pace -- and the plate is the only quest-only fighter armour here with real
-- steel on it, because a Last Stand that triggered on a stiff breeze would trigger in every fight.
--
-- utility_veterans_resolve grants the same rule from a cell.
return {
    name = "Last Stand Plate",
    description = "Falling below 40% health once: raise a barrier and gain +4 Damage for the battle.",
    flavor = "The Colosseum's armourers fit it to fighters they have watched lose. It is not offered to the others.",
    sprite = "assets/items/armor_last_stand_plate.png",
    type = "armor",
    tags = { "heavy", "plate" },
    class = "fighter",
    traits = { "trait_last_stand" },
    bonus = { defense = { 9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18 }, movement = -2 },
    resist = { physical = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
}
