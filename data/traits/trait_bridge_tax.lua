-- BRIDGE TAX: the Toll-Troll's drop, The Toll rebuilt for a person (data/items/utility/utility_bridge_tax.lua).
-- Approved 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- Narrower than the troll's in two ways the review set: it answers ABILITIES only, and it reaches 2 tiles whatever
-- is in hand. And it is billed like every other answer -- a swing's own price, doubled for each answer already
-- thrown since the bearer last acted (models/sloth_trolls.lua) -- because a free strike on every cast in reach would
-- be the best charm in the game.
return {
    name = "Bridge Tax",
    description = "A foe that uses an ability within 2 of you is struck first, for a swing's stamina.",
    toll = { radius = 2, abilitiesOnly = true, priced = true },
}
