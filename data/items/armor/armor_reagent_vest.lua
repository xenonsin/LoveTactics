-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- THE FIRST ARMOR IN THE GAME WITH AN `aura` BLOCK. Every other aura in the catalog is a charm
-- (`utility`) or a coating (`consumable`) -- docs/classes.md draws that distinction as a two-row table
-- and armour is in neither row. This is the third case, and it is worth being explicit about what it
-- means: an armour-typed aura is PERMANENT, exactly like a charm's, because Combat.auraSpent only
-- depletes consumables. Nothing new was needed in the engine; the row simply had never been written.
--
-- What it radiates is the alchemist's whole hand, aimed at the eight cells around it: the vials
-- sitting beside it hit harder (`amountBonus`) and carry the vest's own rot into whatever they touch
-- (`grantTags`). A bomb beside this is a poisoned bomb; a draught beside it is a bigger draught.
--
-- `appliesTo = { "consumable" }` is the constraint that keeps it on this shelf rather than on every
-- shelf. It sharpens nothing the wearer casts and no weapon they swing -- only the things they THROW
-- and DRINK, which is the one category envy owns outright. An armour that buffed adjacent weapons
-- would be a fighter item wearing a lab coat.
--
-- The grid consequence is the point of the whole design: the vest wants to sit in the CENTRE cell,
-- surrounded by eight vials, which is a loadout with no weapon in it and no armour anywhere else. It
-- is the most committed build in the game and its defense line is deliberately close to nothing --
-- because a character who has made that commitment should be terrifying and should die to a stiff
-- breeze.
return {
    name = "The Reagent Vest",
    description = "Adjacent consumables hit harder and carry poison.",
    flavor = "The Crucible issues it to the ones who stopped asking what a thing does and started asking what it does next.",
    sprite = "assets/items/armor_reagent_vest.png",
    type = "armor",
    tags = { "leather", "poison" },
    class = "alchemist",
    aura = {
        appliesTo = { "consumable" }, -- only what the wearer throws and drinks; never a weapon
        amountBonus = 3,
        grantTags = { "poison" },
    },
    bonus = { defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
}
