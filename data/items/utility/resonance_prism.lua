-- Resonance Prism: the mage's Alchemic Mastery. A charm with no ability of its own whose aura raises
-- the MAGNITUDE of the magical things sitting adjacent to it in the 3x3 grid (diagonals included) --
-- a Fire Bolt next to it bites deeper, a Fireball lands heavier, an enchanted blade cuts harder.
--
-- The one new thing it needs is `requiresTags`: every aura before this narrowed by item TYPE, and
-- "magic" is not a type -- a spell is an `ability`, an enchanted sword is a `weapon`, and they are the
-- same school. So the prism applies to both types and then filters by the `magical` tag, which is the
-- same tag the damage core reads to route a hit through magicDefense (see Combat.auraApplies). The
-- prism sharpens exactly the things that count as magic when they land, and cannot drift out of step
-- with that, because it is asking the same question.
--
-- Compare the shelf it completes:
--   * Fire Stone       -- grants a TAG to its neighbor (turns a blade elemental).
--   * Alchemic Mastery -- raises the magnitude of adjacent CONSUMABLES (a type).
--   * Resonance Prism  -- raises the magnitude of adjacent MAGIC (a school).
-- Three auras, three different axes to build a grid around, and a mage now has a reason to care where
-- in the nine cells its spells actually sit.
--
-- Deliberately does NOT touch a healing spell: `magical` is a damage-school tag and the priest's
-- restoratives don't carry it, so the prism is a damage relic. The heal-boosting charm is a different
-- item that does not exist yet, and should not quietly be this one.
return {
    name = "Resonance Prism",
    description = "A tuned crystal. Adjacent magic -- spells and enchanted arms alike -- strikes harder.",
    sprite = "assets/items/resonance_prism.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 320,
    repRank = 2,
    aura = {
        appliesTo = { "ability", "weapon" }, -- a spell and an enchanted blade are the same school
        requiresTags = { "magical" },        -- ...and only the ones that actually ARE magic
        amountBonus = { 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 10 }, -- added to the neighbor's ability magnitude
    },
}
