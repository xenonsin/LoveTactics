-- The Distant Sigil: the first of the Arcanum's five sigils, and the shortest to explain -- the magic
-- sitting beside it in the 3x3 grid reaches further.
--
-- THE SIGILS. Five charms, one idea: an Arcanum mage does not learn new spells, it learns to cast the
-- ones it has differently. Each sigil takes a single property of a neighbouring working and bends it --
--
--   Distant   (this)     -- it reaches further          (`rangeBonus`)
--   Careful              -- it spares your own line     (`careful`)
--   Twinned              -- it forks into a second body (`twin`)
--   Quickened            -- it costs less tempo         (`speedBonus`)
--   ...and the Empowered one, which is the RESONANCE PRISM
--   (data/items/utility/utility_resonance_prism.lua) -- it lands harder (`amountBonus`). It was on the
--   shelf years before the other four were written and it is not renamed here, because a second charm
--   with the same field and a tidier name would be exactly the `+n` docs/weapons.md exists to forbid.
--   The family is four new sigils and one old prism; the prism is the reason the family was possible.
--
-- They are the reason to care where in the nine cells a spell actually sits, and they are deliberately
-- all of one shelf: pride's whole claim is that the craft matters more than the catalogue. A knight
-- with one Fireball and four sigils around it is casting a different Fireball to the one the Arcanum
-- sold, and that -- not a longer spell list -- is what the Arcanum thinks mastery is.
--
-- Distinct from the Long-Fuse Reagent (data/items/utility/utility_long_fuse_reagent.lua), which is the
-- alchemist's version of the same field: that one lengthens a THROW (`appliesTo = consumable`) because
-- the Crucible's reach problem is an arm, and this one lengthens a WORKING (`requiresTags = magical`)
-- because the Arcanum's is a line of sight. Same number, two different problems, two shelves.
--
-- What it changes about how a mage is played rather than how hard it hits: range is what decides
-- whether the caster has to stand where it can be reached. Two tiles is the difference between casting
-- from behind the knight and casting from beside them.
return {
    name = "Distant Sigil",
    description = "Adjacent magic reaches further.",
    flavor = "First-year work. The Arcanum sets it as an exercise and sells it as a relic.",
    sprite = "assets/items/utility_distant_sigil.png",
    type = "utility",
    tags = { "arcane", "sigil" },
    class = "mage",
    price = 280,
    repRank = 2,
    aura = {
        appliesTo = { "ability", "weapon" }, -- a spell and an enchanted wand are the same school
        requiresTags = { "magical" },        -- ...and only the ones that actually ARE magic
        rangeBonus = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 }, -- added to the neighbour's reach
    },
}
