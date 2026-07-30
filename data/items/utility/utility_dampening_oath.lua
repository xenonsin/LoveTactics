-- Dampening Oath: the knight half of the Spellbreaker (knight x mage). Enemy workings cast within three
-- tiles of you cost double mana.
--
-- A tax rather than a denial, and that is the shelf's whole settled shape. Four active anti-magic items
-- were drafted for this discipline across two rounds -- an interrupt, a silencing zone, a counterspell,
-- a dispel-strike -- and every one was turned down. The read that survives: refusing somebody their turn
-- is not the fun part of playing against a caster. This never refuses anything. The enemy mage casts
-- exactly what it meant to and finds out afterwards it can afford one fewer.
--
-- Mana only. An oath does not make a swing tire you faster, and a spellbreaker standing in a line of
-- fighters is carrying dead weight -- which is correct, because it is an anti-mage charm.
--
-- Note the tax lands at the SPEND, not at the button: a caster who could just afford a spell commits to
-- it and then finds the pool empty. Being taxed into nothing is the threat, and warning them would
-- defuse it.
return {
    name = "Dampening Oath",
    description = "Enemy spells cast within three tiles of you cost double mana.",
    flavor = "He says nothing at all. That is, in fact, the working.",
    sprite = "assets/items/utility_dampening_oath.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    discipline = "spellbreaker",
    price = 440,
    unlockQuests = 10,
    traits = { "trait_dampening_oath" },
}
