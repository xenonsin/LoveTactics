-- The item that carries Adrenal Surge (data/traits/trait_adrenal_surge.lua): every blow that lands on the
-- wearer pulls their next turn sooner.
--
-- A passive utility whose whole effect is the trait it grants, like the Duelist's Reflex or the
-- Reprisal Quiver beside it on the shelf. Sold by the fighter's vendor -- wrath's line, and there is no
-- better statement of it than a body that answers being hurt by getting there faster (see docs/story.md).
--
-- BARBARIAN, not the open fighter shelf. Rage is "damage climbs as your own health falls" and this is
-- the same bargain paid in initiative rather than in damage: it only ever pays a body that is being
-- opened up. Slot and price are the grade ledger's own placement for it (`grade-report diff`, 3.4
-- against the fighter house) rather than the shelf position it inherited from the open racks: it
-- graded four rungs above the gate it used to sit on, and a discipline item may not sit below slot 3
-- in any case (docs/classes.md).
--
-- Note it wants the opposite build from every other defensive item in the game: it pays out when you are
-- struck, so stacking armor until nothing lands turns it off. The fighter who runs this wants to be in
-- the middle of it.
return {
    name = "Adrenaline",
    description = "Every blow you take pulls your next turn sooner.",
    flavor = "Wrath is a kind of speed. Armour it away until nothing lands and you have bought a belt that does nothing.",
    sprite = "assets/items/adrenal_surge.png",
    type = "utility",
    tags = { "belt" },
    class = "barbarian", -- deeper cut of the shelf: buyable only once the barbarian gate is cleared
    price = 495,
    unlockQuests = 5,
    traits = { "trait_adrenal_surge" },
    -- the item is tempo, bought with being hit
    bonus = { speed = 2 },
}
