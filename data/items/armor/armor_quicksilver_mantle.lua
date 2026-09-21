-- KILL A SIN, WEAR IT -- and here, kill the thing that adapts and adapt. The King Slime's own rule
-- (data/traits/trait_adaptive.lua) lifted off the body and handed to somebody who has to decide
-- whether they want to be that: take an elemental blow, and for a breath you are proof against that
-- element and your own blows carry it.
--
-- ONE TRAIT, TWO BODIES, ONE FIGURE BETWEEN THEM -- which is exactly what `traitParams` is for
-- (Trait.param: "what lets one trait blueprint serve two items that only disagree about a figure").
-- The King's adaptation holds 40 ticks, about eight turns, because the fight is built on the player
-- running out of elements before it runs out of memory. This one holds 8 -- one turn and a breath --
-- and that single number is the whole difference between a body that walls an element for a fight and
-- a coat that answers one blow. The rule is identical; the window is not.
--
-- WHY A WINDOW AND NOT A RESISTANCE. The obvious tuning was to grant `Resistant: <Type>` instead of
-- `Immune: <Type>` and let it last -- softer, longer, safer. It was the wrong instrument twice over.
-- A resistance is a subtraction that floors at 1 (docs/vulnerability.md) and would read as "slightly
-- less fire", which is not what the player watched the King do; and the OUTGOING half rides the
-- immunity itself -- Combat.strikeElement reads the element off the ward the bearer is wearing -- so
-- a resistance would have quietly delivered half the item and named the other half in prose. Short
-- and categorical keeps both halves true.
--
-- IT IS REACTIVE, WHICH IS ITS PRICE. Nothing happens until something elemental lands on you, so it
-- is worth everything on a fire floor and nothing at all against a company of swordsmen -- the same
-- shape as the Ravener's Hide, which pays only while you are landing blows. A build that wants it is
-- a build that has decided to stand in front of the casters.
--
-- The mantle itself is thin on purpose. A body wearing the King's rule is already answering one whole
-- damage type at a time; armour in the middle of that would blur what the piece is for.
--
-- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many the company
-- carries out, and none will buy one back (`unstocked`, answered at Vendor.foundPrice). It is still
-- yours -- move it between your own bodies, forge it, break it down -- it is simply not merchandise.
local Curve = require("models.curve")

return {
    name = "Quicksilver Mantle",
    description = "On elemental damage taken: become proof against that element for a turn, and strike with it.",
    flavor = "Whatever you show it, it has already started becoming.",
    sprite = "assets/items/armor_quicksilver_mantle.png",
    type = "armor",
    tags = { "cloth" },
    -- The Crucible's vocabulary: the three coats that DRINK an element are alchemist stock
    -- (Salamander Hide, Rimecloth, Stormcloth), and this is the one that drinks whichever it is
    -- handed. Same shelf, same sentence, one rung of cleverness up.
    class = "alchemist",
    -- SIX IS THE TOOL'S OWN ANSWER, not a number typed here: `. drop-tier` grades the mantle at 10.7
    -- turns of advantage and spreads it to 6. Left agreeing with the pass on purpose -- what a thing
    -- is worth sets where it sits (docs/shelf.md), and a boss relic is not exempt from its own grade.
    unlockLevel = 10,
    unstocked = true,
    traits = { "trait_adaptive" },
    -- ONE TURN AND A BREATH. Status.TICKS_PER_TURN is 5, so 8 ticks is the blow you just took plus the
    -- turn you get to answer with -- long enough to matter on the exchange it fired on, far too short
    -- to be a stance you live in.
    traitParams = { duration = 8 },
    -- EVERY COAT COSTS A SQUARE OF PACE (docs/classes.md, tests/armor_spec.lua), and this one is no
    -- exception for being clever: a mantle heavy enough to take an element is a mantle you walk in.
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
}
