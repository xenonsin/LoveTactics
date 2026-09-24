-- RANK: Pride's slime rule. Ranked bodies of one side keep an ORDER by current health, and only the lowest
-- can be hurt -- the rest are warded until those beneath them fall (Status.immuneToDamage answers it, so
-- the preview and the log say "Outranked"). Kill from the bottom up.
return {
    name = "Rank",
    description = "While a lower-ranked body of its side stands, it can't be hurt. Lowest health ranks lowest.",
    ranked = true,
}
