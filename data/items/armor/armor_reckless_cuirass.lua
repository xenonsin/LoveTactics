-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- THE ONLY ARMOR IN THE CATALOG WITH A NEGATIVE RESIST. Combat.mitigatedDamage subtracts `resist`
-- from the incoming number (models/combat.lua) and never floors the term, so a negative entry simply
-- adds -- and the breakdown tooltip already prints signed rows for it, labelled honestly, because that
-- is how a Wet unit under fire has always read.
--
-- The mechanic is not new: utility_demonic_essence has carried `holy = -8` since Demon Bane needed
-- somewhere to bite, and that file is the one that proved the sign works. What is new is the SHELF.
-- The essence is a creature's flesh -- `noSteal`, `noCopy`, nothing anybody chose -- so a negative
-- resist has only ever been something a monster IS. This is the first one a player can put on, which
-- makes it the first time the sign is a purchase rather than a species.
--
-- So this is armour that makes you EASIER TO KILL and hits harder for it. Not a trade of defense for
-- damage -- a trade of a whole damage SCHOOL for damage. Physical blows land for more than they would
-- against a bare chest, and in exchange the wearer's own swings carry weight nothing else on the shelf
-- provides passively.
--
-- Wrath's sharpest statement, and the item this shelf was missing: every other fighter piece here pays
-- out for being hurt (Last Stand, Adrenal Surge, the Unappeased). This one does not pay you for being
-- hurt. It arranges to have you hurt, and hands you the weapon first. status_reckless says the same
-- thing as a status; the cuirass says it as a permanent decision.
--
-- Note it is deliberately narrow: `physical` only. A mage's fire arrives at the usual price, so the
-- cuirass is worst against exactly the enemies a fighter was already worst against, and does not turn
-- into a general-purpose glass cannon.
--
-- No movement penalty. There is barely anything here to carry.
return {
    name = "The Reckless Cuirass",
    description = "Adds real Damage, and physical blows land on you harder than with no armor at all.",
    flavor = "The Colosseum's smiths cut the plate away where it was slowing the swing, and then kept going.",
    sprite = "assets/items/armor_reckless_cuirass.png",
    type = "armor",
    tags = { "plate" },
    class = "fighter",
    bonus = { damage = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 }, defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
    -- NEGATIVE on purpose: see the header. This is the one blueprint in the game that adds to incoming
    -- damage rather than subtracting from it, and the sign is the whole item.
    resist = { physical = { -3, -3, -3, -4, -4, -4, -4, -5, -5, -5, -6 } },
}
