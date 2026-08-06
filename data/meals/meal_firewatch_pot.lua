-- Elemental Resistance Up, and it is a COUNTER-PICK rather than a general good -- which is the whole
-- reason it is on a menu you re-read before every quest instead of on a shelf you buy from once.
--
-- The Crucible sells the same answer as three separate coats (Salamander Hide, Stormcloth, Rimecloth),
-- one element and one body each, six points apiece. This is all three at half the magnitude, on
-- everybody, for one run. So it never beats the right coat on the right member -- what it beats is not
-- owning three coats and not knowing which of them today's map wanted.
--
-- `resist` is flat subtraction on the tagged damage type, folded in exactly as an armour's is
-- (Combat.applyUnitPassives), so it stacks with the coats rather than replacing them: a salamander-hide
-- knight who also drank here takes 9 off a fire blow.
return {
    name = "The Firewatch Pot",
    description = "The company takes less from fire, ice and lightning alike for the quest.",
    flavor = "Named for the ones who drink it: the people who sit up all night with the buckets already full.",
    price = 140,
    unlockPrestige = 4,
    resist = { fire = 3, ice = 3, lightning = 3 },
}
