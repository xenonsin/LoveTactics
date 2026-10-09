-- THE FIRST ARCHON: the Hollow Crown's organ, carrying its four phases (data/traits/trait_hollow_crown.lua,
-- models/hollow_crown.lua; "The Crown's Bestiary", slice D). Creature kit: bound, unstealable, on no shelf -- a rogue
-- that could lift it would lift the last fight of the game off the body.
--
-- IT CARRIES THE GULLET TOO (data/traits/trait_gullet.lua), because the Crown swallows when it acts Gluttony and the
-- rule that lets the body out belongs to whatever does the eating: a stun on it, or its death. `share` is the
-- approved tenth -- one blow of a tenth of its health spits the body out -- and the trait's own phases count the same
-- tenth across every blow (HollowCrown.damaged), which is the approved "free it by dealing a tenth of its health".
--
-- It used to be the Hollow Crown itself, an armour in the centre cell. That id is the company's relic now
-- (data/items/armor/armor_hollow_crown.lua), so the body's half took a name of its own.
return {
    name = "The First Archon",
    description = "Four phases: its court, its seven wants, the Pit, and the Last Hour. A tenth of its health frees what it swallows.",
    flavor = "The seven wants were all its own. Seven people carried them off, and it let them.",
    sprite = "assets/items/utility_the_first_archon.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_hollow_crown", "trait_gullet" },
    traitParams = { share = 0.1 },
}
