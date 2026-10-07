-- THE THIN SMILE: the Wasting One's rule, and the Plague Knight's once it is carried out (data/items/utility/
-- utility_smiles_at_pain.lua, utility_the_thin_smile.lua). Reviewed 2026-10-06 ("Envy's Bestiary", round 4).
--
-- Ovid's Envy never smiles except at another's pain. Every wound a foe of the bearer takes where the bearer can see
-- it heals the bearer by `heal`. The flag is read from Combat.dealFlatDamage (models/envy_oneoffs.lua's thinSmile),
-- the one funnel every wound runs through, so a flag with no hook is the whole rule: no wound is missed.
return {
    name = "The Thin Smile",
    description = "Heals 2 whenever a foe it can see takes a wound.",
    smilesAtPain = true,
    heal = 2,
}
