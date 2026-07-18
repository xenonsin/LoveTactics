-- Caltrop Greaves: the Pilgrim's Sandals read from the hunter's shelf. Where the sandals hallow the
-- road behind them, these sow it -- a caltrop (data/traps/caltrops.lua) dropped on every tile the
-- wearer steps off, sided to the wearer so its own line walks the corridor safely.
--
-- Scattered behind rather than underfoot, as every trail is (Combat.layTrail), and for these it reads
-- as exactly what caltrops have always been for: what you throw down at the ground you are giving up.
-- A hunter falling back leaves the pursuit a floor it has to pay for. Note the wearer is not spared by
-- any rule of its own here -- it is spared because caltrops never trigger on their owner's side.
--
-- The one trail in the game that leaves a TRAP rather than a hazard, and the difference is the whole
-- item (see Combat.layTrail). A hazard trail is ground that fades: it is a threat for a turn and then
-- the corridor is open again. Caltrops have no duration at all. They lie where they fell for the rest
-- of the battle, invisible to an enemy carrying no detector, and are spent one foe at a time. So the
-- sandals are a thing you do to THIS turn's fight, and these are a thing you do to the MAP: pace a
-- chokepoint early and the ground stays yours until someone pays to cross it.
--
-- Traps are hunter's keyword (docs/classes.md) and this is the shelf's purest statement of it -- setup
-- now, payoff later -- but bought rather than cast: no turn is spent, only the walking you were doing
-- anyway. The price carries that, being dearer than boots that merely dodge traps (Feather Boots, 220).
return {
    name = "Caltrop Greaves",
    description = "Scatters caltrops on every tile you leave: the ground behind you turns against the enemy.",
    flavor = "A hunter does not chase what it can simply make the ground charge for.",
    sprite = "assets/items/caltrop_greaves.png",
    type = "utility",
    tags = { "boots" },
    class = "hunter",
    price = 380,
    repRank = 2,
    -- No `duration`: a trap is an object left lying there, not ground that ages out. It waits.
    trail = { trap = "caltrops" },
}
