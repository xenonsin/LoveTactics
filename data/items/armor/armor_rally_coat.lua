-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- A banner you carry instead of plant. `incense` is ground that WALKS (Combat.layIncense), and
-- hazard_rally is the fighter's own banner ground -- allies standing in it are Inspired: raised Damage
-- and Defense (status_inspiration).
--
-- The distinction the file exists to make is drawn in Combat.layIncense's own header: a banner STAYS,
-- a trail is LEFT, incense WALKS. Everything the fighter's shelf has ever done with morale has been
-- the first kind -- weapon_marching_standard nails the line to a square of ground, and its whole
-- character is that the square does not move. This is the same effect with that constraint deleted,
-- and deleting it changes what the item is for: a planted banner holds an objective, a worn one leads
-- a charge.
--
-- It skips its own wearer (see hazard_rally: a standard does not rally itself), so the coat is worth
-- exactly the number of allies willing to march inside one tile of the person wearing it. A fighter in
-- this who runs ahead of the line is wearing nothing.
--
-- No trait, no reflex, and almost no steel. Warlord stock (docs/classes.md names the subclass and
-- cannot yet sell it), and the first piece of it that is not a polearm.
return {
    name = "Rally Coat",
    description = "Carries a banner's ground with you: allies standing beside you are Inspired.",
    flavor = "The Colosseum stitches the company colours into the lining, where only the wearer's own line can see them.",
    sprite = "assets/items/armor_rally_coat.png",
    type = "armor",
    tags = { "cloth", "banner" },
    class = "fighter",
    incense = { hazard = "hazard_rally", radius = 1 },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 }, movement = -1 },
}
