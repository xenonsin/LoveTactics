-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Taking a hit pulls the wearer's next turn sooner (trait_adrenal_surge). The beating is the approach.
--
-- THE ONLY ARMOR IN THE GAME THAT TOUCHES INITIATIVE, and initiative is the one currency nobody gets
-- back -- docs/classes.md says as much about the Quickened Sigil, which is the only aura field allowed
-- near it. So the harness is doing something no defensive slot has ever been able to do: it does not
-- reduce the damage, it changes WHEN you answer for it.
--
-- Which quietly rewrites how a fighter opens. Every other armour makes walking into the enemy line
-- survivable; this makes it profitable, because the enemy's alpha strike is now the thing that hands
-- the fighter the next turn. Run in, get hit by three people, act again before any of them.
--
-- It is worth nothing at all if nobody attacks you, which is the correct failure case for a wrath
-- item and the reason it can be this strong: a Whirlplate wearer or a taunting knight is the ideal
-- body for it, and a careful one gets a plain jerkin with a stat line.
--
-- utility_adrenal_surge is the charm form.
return {
    name = "Adrenal Harness",
    description = "Taking a hit pulls your next turn sooner.",
    flavor = "The Colosseum sells it to fighters who have noticed that the crowd pays for the second round.",
    sprite = "assets/items/armor_adrenal_harness.png",
    type = "armor",
    tags = { "leather" },
    class = "fighter",
    traits = { "trait_adrenal_surge" },
    bonus = { defense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
    resist = { physical = { 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4 } },
}
