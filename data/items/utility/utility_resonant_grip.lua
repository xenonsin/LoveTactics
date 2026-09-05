-- Resonant Grip: the fighter half of the Battlemage (fighter x mage). Your weapon strikes carry the
-- element of whatever you last cast.
--
-- The author's own correction, and it is the better item by some distance. This was drafted as a
-- greatsword -- "swings carry the element of your last cast" -- and as a weapon it was a tax: a
-- battlemage who wanted the discipline's signature had to give up whatever they were actually holding.
-- As a charm it attaches to a spear, a censer, a bow, bare hands, anything, and the discipline stops
-- being an argument about which sword you own.
--
-- It grants a TAG rather than a damage number, which is what makes it interesting rather than merely
-- large. Elemental tags reach armour `resist`, the field interactions (a lightning strike arcing out
-- into water, a fire blow biting a body left Wet) and the scaling all at once -- so the same clause is
-- brilliant against a soaked line and worthless against a rimeguard, and the battlemage's job is to
-- have thrown the right spell one turn earlier.
--
-- Spells are untouched: a Fireball keeps being fire. Only the steel remembers.
return {
    name = "Resonant Grip",
    description = "Weapon strikes carry the element of your last cast.",
    flavor = "The heat does not leave the hand. It is simply told, afterwards, where to go.",
    sprite = "assets/items/utility_resonant_grip.png",
    type = "utility",
    tags = { "charm" },
    class = "battlemage",
    unlockQuests = 3,
    dropTier = 3,
    traits = { "trait_resonant_grip" },
    -- steel carrying a working is a magical weapon in the hand
    bonus = { magicDamage = 2 },
}
