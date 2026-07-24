-- Spell Eater: the standing rule of the Spellbreaker's charm. Magical blows land lighter on the bearer,
-- and the difference is refunded to them as mana.
--
-- A flag (Trait.flag) read in Combat.dealFlatDamage, after the negating reflexes and before mitigation --
-- so it is a discount on a blow that is really going to land, not a fourth way of voiding one.
--
-- Anti-magic as ABSORPTION, which is the one shape of it the author did not turn down across four
-- rounds. Every rejected version refused the enemy something; this one lets the spell through, takes it,
-- and hands the spellbreaker the fuel. The caster still gets to cast, and gets to watch it pay for the
-- answer.
--
-- The refund IS the eaten half, so there is one number to tune rather than two, and an item that
-- absorbed more would automatically feed more. `magnitude` is that share, in percent.
return {
    name = "Spell Eater",
    magnitude = 40, -- percent of an incoming magical blow swallowed, and refunded as mana
    eatsMagic = true,
}
