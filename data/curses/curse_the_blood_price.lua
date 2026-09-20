-- THE BLOOD PRICE: mana stops being the currency, and the bearer has no say in it.
--
-- THE OVERDRAFT, NOT SOLD BUT DEALT (`rules.manaToHealth`, rewritten on Combat's one spend path).
-- utility_overdraft is a charm a caster CHOOSES to wear because casting out of an empty pool is worth
-- blood to them. This is the same inversion arriving unasked, on whoever happens to be holding the piece.
--
-- WHICH MAKES IT THE ONE HEX IN THE FOLDER THAT MIGHT BE A GIFT, and it is deliberately left as one. On
-- the company's mage it is a serious wound: every spell now comes out of the health bar, and the share a
-- wound has already reserved cannot be healed back into (models/wound.lua). On a knight who casts
-- nothing it does nothing at all, and on a big body with a small pool it is a genuine upgrade. A curse
-- whose value depends on who is carrying it is a curse the player could ANSWER by moving it -- except
-- that it binds, so the answer is the rite or the fee, which is the room working as designed.
--
-- IT WOUNDS AND NEVER FELLS. The conversion floors the caster at one health, which the spend path argues
-- at length: a rule that empties a body is not a price, it is a delete, and nothing on that path would
-- even run killUnit properly.
return {
    name = "The Blood Price",
    description = "The bearer pays every mana cost in health instead, and cannot put the piece down.",
    binds = true,
    depth = 9,
    fee = 260,
    rules = { manaToHealth = 1.0 },
}
