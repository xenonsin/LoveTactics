-- Reaper's Ledger: the hunter's Reaper grid piece (docs/engines.md). A kill landed by a weapon beside it
-- refunds that blow's cost and hands the bearer two free steps toward the next one
-- (trait_reapers_ledger). Packs of weak bodies are what it is for; a lone boss gives it nothing, which
-- is the point.
return {
    name = "Reaper's Ledger",
    description = "A kill with a weapon next to it refunds the blow's cost and grants 2 free steps.",
    flavor = "The Lodge keeps one per hunter. Nobody reads them but the hunter.",
    sprite = "assets/items/utility_reapers_ledger.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    unlockLevel = 7,
    traits = { "trait_reapers_ledger" },
    bonus = { skill = 1 },
}
