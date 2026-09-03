-- Wellspring Sandals: worn thin at the sole, and worth more to the people walking behind you than to
-- you. Every tile the wearer steps OFF fills with mana, and the ally who steps in it drinks it.
--
-- MANA DOES NOT REGENERATE IN THIS GAME. That is a hard rule with exactly one standing exception (an
-- Arcane Reservoir bearer, at one point a tick -- see Combat.ARCANE_REGEN), and the rule is what makes
-- every mage turn a real decision rather than a rotation. So a party-wide refill is a large thing to
-- sell, and everything about how this is limited follows from that:
--
--   * THE PARTY MUST WALK YOUR LINE. A print is laid behind, one per tile crossed, and lives about two
--     turns -- so the mana is real only if the company routes through a wake somebody else chose. That
--     is a position cost paid by four bodies, on a board where standing together is what area damage
--     exists to punish, and it is what a spare turn used to buy.
--   * ONE MOUTHFUL PER PRINT. The tile is spent by the body that drinks it (hazard_wellspring's
--     `ctx.consume`), so a caster cannot pace across the same puddle and mint mana out of it.
--   * THE WEARER GETS NOTHING. A trail is always laid behind (Combat.layTrail), so you can never stand
--     in your own print, and there is deliberately no `selfStatus` to hand the sacrament back the way
--     Pilgrim's Sandals does -- a pair of boots that refilled its own wearer would be a second Arcane
--     Reservoir, and the whole weight of the rule above is that there is only one.
--
-- It was a three-use CONSUMABLE stack that spent a turn to refill everyone adjacent at once, and that
-- was a potion wearing the shape of a shoe: the object was footwear and the mechanic was a flask. In
-- this game footwear is a `trail` -- ground you leave, the walking being the thing (Pilgrim's Sandals,
-- data/items/utility/utility_pilgrims_sandals.lua) -- and the flavor line below was already written for
-- the version it has now. Losing the stack lost the limiter with it; the three bullets above are what
-- replaced it, and the price rose accordingly (models/grade.lua no longer applies the one-shot discount
-- a consumable earns for being gone after one use).
--
-- Still the Crucible's, though the old argument for that is gone with the stack ("a `consumesItem` that
-- hands somebody else a resource back" -- envy's vocabulary twice over -- described an item that no
-- longer exists). What is left is the true half: the Crucible brews the Mana Potion, this is the
-- party-wide reading of it, and lending a pool you are not casting out of yourself is the shelf's own
-- sentence (docs/classes.md). Being FOOTWEAR rather than a flask is flavor, not a second craft.
--
-- What it actually buys is a second Fireball, or a second seal, or the Stilled Hour the mage could not
-- otherwise afford. In a two-caster party that follows its scout it is one of the strongest items on
-- this list; in a party of fighters it is a slot somebody wasted, and the shop tooltip is quite honest
-- about which.
return {
    name = "Wellspring Sandals",
    description = "Every tile you leave fills with mana: the first ally to walk through it drinks 8 back.",
    flavor = "Somebody walked a very long way in these, and did not arrive anywhere in particular.",
    sprite = "assets/items/utility_wellspring_sandals.png",
    type = "utility",
    tags = { "boots", "arcane" },
    class = "alchemist",
    -- Derived, not chosen: slot 0 sets the price (docs/shelf.md, `. grade-report`). It was 30 as a
    -- consumable and is 80 as a charm for one reason -- the grader's `consumable = 0.4` multiplier is
    -- the discount a thing earns for being gone after one use, and this is not gone after one use.
    price = 80,
    unlockQuests = 0, -- opening shelf: a two-caster party should be able to buy this on day one
    -- Matched to Pilgrim's Sandals' print (10 ticks, ~2 turns) for the same reason it is: a puddle that
    -- dried inside half a turn would be gone before the company behind could reach it, and the company
    -- reaching it is the entire item. No `selfStatus` -- see the header.
    trail = { hazard = "hazard_wellspring", duration = 10 },
    -- footwear moves you; the mana behind you is the flourish
    bonus = { movement = 1 },
}
