-- THE MISTCLOAK: the Vampire Duelist's drop (data/items/armor/armor_mistcloak.lua). Mist Step made a garment,
-- and made AUTOMATIC on Keno's round-1 note ("don't pick, be auto"): the first blow each fight does no damage,
-- and the wearer re-forms on the free tile 2 away that is farthest from whoever struck. No Bleed rides with it.
return {
    name = "Mistcloak",
    description = "The first blow each fight does no damage: you re-form 2 tiles away, as far from the attacker as you can.",
    mistsOnHit = "fight",
}
