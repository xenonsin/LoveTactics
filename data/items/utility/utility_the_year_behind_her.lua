-- THE YEAR BEHIND HER: the sow's bound relic, carrying the one rule her fight is about.
--
-- Shaped on utility_the_iron_in_him -- a `bound` creature utility whose only job is to hold a boss's
-- trait -- and named the same way: for the THING that explains the rule rather than for the rule. The
-- Unseeing is named for the shot somebody left in him; she is named for what she has spent a year
-- keeping alive. Neither name says what the mechanic does, which is how a player meets it as a fight
-- instead of as a tooltip.
--
-- `bound` locks it in the centre cell, so the rage is not a thing a Disarm or a pickpocket can take off
-- her mid-fight. Natural kit, so: no class beyond `creature`, no price, no dropTier, noSteal -- a boss's
-- own rule must never be minted into the drop pool (docs/bestiary.md, and the seventeen items that
-- learned it the hard way).
return {
    name = "The Year Behind Her",
    description = "If her cub falls, she stops keeping anything back.",
    flavor = "Everything she has done since the thaw is standing just behind her.",
    sprite = "assets/items/utility_the_year_behind_her.png",
    type = "utility", -- `bound` (not the type) is what locks it in the centre cell
    class = "creature",
    tags = { "signature", "relic" },
    bound = true,
    noSteal = true,
    -- BOTH DIRECTIONS OF ONE BOND, on one object. She rages if the cub falls (trait_bereaved); the cub
    -- leaves if she does (trait_orphaned). Kept together here rather than split across the two sheets
    -- because character_bear is road stock met on its own -- see trait_orphaned's header.
    traits = { "trait_bereaved", "trait_orphaned" },
}
