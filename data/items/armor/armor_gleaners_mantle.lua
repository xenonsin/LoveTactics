-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Banks a charge whenever ANYONE nearby works a spell (trait_gleaning) -- the party's casters, the
-- enemy's, it does not care whose. The mantle does not produce magic; it takes a cut of everyone
-- else's.
--
-- The only item in the catalog whose value is set by how magical the WHOLE BOARD is, which makes it
-- the first piece of gear that is worth reading the enemy roster before equipping. Against a warband
-- of swords it banks nothing all fight. In an Arcanum duel it pays on both sides of the exchange, and
-- the enemy cannot stop feeding it without also declining to cast.
--
-- Filed under pride rather than envy, and the line is thin enough to be worth stating: envy covets a
-- specific person's power and spoils it (see the Crucible's shelf). This does not care who cast, takes
-- nothing away from them, and simply assumes the working was partly its own. That assumption is the
-- sin.
--
-- utility_gleaning_rod is the charm form. Cloth: a square of pace.
return {
    name = "Gleaner's Mantle",
    description = "Banks a charge whenever anyone nearby works a spell.",
    flavor = "The Arcanum rules that ambient working is unowned. The ruling was written by people wearing these.",
    sprite = "assets/items/armor_gleaners_mantle.png",
    type = "armor",
    tags = { "cloth", "arcane" },
    class = "mage",
    traits = { "trait_gleaning" },
    bonus = { magicDefense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, movement = -1 },
    resist = { magical = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
}
