-- The Thrill of the Hunt: a Poacher's charm that pays the setup back in TEMPO. Carries
-- trait_thrill_of_the_hunt -- fell a foe you had Marked, Bled, Rooted or Crippled and the turn is
-- handed straight back, once a turn.
--
-- WHAT IT FIXES ON THE SHELF. Hunter is the setup-then-payoff class, and every payoff it has ever sold
-- is a bigger number against a body you prepared: Quarry's Due, the Marksman's Lens, the Culler's Kit.
-- All of them make the second shot HARDER. None make it cheaper. So the honest complaint about playing
-- a hunter is that the setup turn is a turn you did not get to fight in, and the arithmetic has to be
-- generous to make up for it. This pays in the currency the setup actually cost -- a turn -- rather
-- than trying to make one turn's damage worth two.
--
-- WHY THE POACHER'S (rogue x hunter). The mark is the hunter's and the opportunism is the rogue's, and
-- what this charm rewards is precisely the seam between them: you do not get the turn back for killing
-- something, you get it back for killing the RIGHT something, the one you had already put a mark on.
-- A Poacher chaining across a field of bled bodies is the discipline working.
--
-- The extra action is real tempo and not free time: Combat.grantExtraAction banks the whole price of
-- the action it re-opens and settles it when the hunter finally stops, so what is bought is ORDER --
-- two actions with no enemy beat between them -- rather than a turn out of nowhere. See the trait for
-- the once-per-turn stamp, which is a termination condition rather than a balance dial.
local Curve = require("models.curve")

return {
    name = "The Thrill of the Hunt",
    description = "Felling a foe you had Marked, Bled, Rooted or Crippled hands your turn back, once a turn.",
    flavor = "The tracking is the work. What comes after is not properly hunting and she has never pretended otherwise.",
    sprite = "assets/items/thrill_of_the_hunt.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    discipline = "poacher", -- multiclass: stocked on the rogue's shelf too once the gate is cleared
    price = 320,
    unlockQuests = 4,
    traits = { "trait_thrill_of_the_hunt" },
    -- A floor for the fights that never present a marked kill. Damage rather than defense: this is a
    -- charm about finishing things, and a hunter short of the kill is short of damage, not of plate.
    bonus = { damage = Curve.ramp(1, 11) },
}
