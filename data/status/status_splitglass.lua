-- Splitglass: a fixed number of blows land on the reflection instead of the body. `negates = "any"`,
-- so unlike the two school-bound barriers it does not ask what is coming -- only how many more times
-- something may come.
--
-- COUNT, NOT SIZE, and that is the whole of the idea. Every other defence in this game is arithmetic:
-- armor subtracts, resist subtracts, a mana shield pays in the wrong pool, a barrier answers one
-- school. All of them get worse against the one blow that matters and better against the ten that
-- don't. This inverts that exactly. Three charges of Splitglass shrug off three arrows or three
-- executions with equal indifference -- so it is worth least against chip damage and most against the
-- swing that was going to end you.
--
-- Priced accordingly: short, and expensive per charge. It is strictly stronger than either single-school
-- ward while it lasts, so it is not allowed to last. The counterplay is the obvious one and it is
-- deliberately cheap -- throw anything at it, three times. A rogue who spends the glass on an arrow is
-- a rogue who has already lost the trade.
return {
    name = "Splitglass",
    abbr = "Splt",
    description = "Splitglass: the next few hits of any kind are turned aside entirely.",
    color = { 0.68, 0.86, 0.90 }, -- badge tint (cracked pale cyan)
    duration = 12,                -- ~2.5 turns: too strong to be allowed to sit
    magnitude = 2,                -- hits it turns aside; the granting ability raises it per level
    negates = "any",
}
