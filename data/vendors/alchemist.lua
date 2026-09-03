-- Alchemist vendor. Its quest line is transmutation -- the base thing made noble, the borrowed
-- property, the stone with no nature of its own -- and ends facing Envy.
--
-- Greed wants the thing. Envy wants the thing's PROPERTY, and would rather you had neither. That is
-- the whole difference between this shelf and the Undercroft's, and the two are balanced against it:
-- a rogue takes your dagger, an alchemist takes what made it sharp.
--
-- It used to be the last vendor to open, on a prestige threshold, on the argument that you do not envy
-- until you have seen what the other six own. All seven wait on the same thing now -- level 1 of their
-- own class (data/buildings/alchemist.lua) -- so the order is whatever this company chose to play, and
-- a house that opens late does so because nobody climbed it.
return {
    name = "The Crucible",
    class = "alchemist",
    description = "Every jar is labelled with something else's name.",
    sin = "envy",
    -- The companion this house's line earns; see data/vendors/bastion.lua for why it is authored here.
    companion = "character_ren",
}
