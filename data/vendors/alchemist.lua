-- Alchemist vendor. Its quest line is transmutation -- the base thing made noble, the borrowed
-- property, the stone with no nature of its own -- and ends facing Envy.
--
-- Greed wants the thing. Envy wants the thing's PROPERTY, and would rather you had neither. That is
-- the whole difference between this shelf and the Undercroft's, and the two are balanced against it:
-- a rogue takes your dagger, an alchemist takes what made it sharp.
--
-- The last vendor to open (prestige 4, see data/buildings/alchemist.lua). You do not envy until you
-- have seen what the other six own.
return {
    name = "The Crucible",
    class = "alchemist",
    sprite = "assets/vendors/alchemist.png", -- shopkeeper portrait; falls back to a placeholder
    description = "Every jar is labelled with something else's name.",
    sin = "envy",
}
