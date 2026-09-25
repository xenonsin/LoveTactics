-- The Helm of Terror: Fafnir's aegishjalmr, "that all living creatures fear". Worn by the Gilt Wyrm as Dread
-- (data/items/utility/utility_wyrm_dread.lua) and lent to the company by the Aegishjalmur
-- (data/items/armor/armor_aegishjalmur.lua).
--
-- A PRESENCE (models/trait.lua): every foe standing within 2 of the bearer moves 2 fewer squares. It is
-- Cowering's own number (data/status/status_cowering.lua), delivered as ground rather than a badge -- the
-- review asked for "a foe that starts its turn within 2 is Cowering", and a live presence says the same
-- thing without a turn-start hook the trait layer does not have: step out of the ring and your legs come
-- back, which is the counterplay the review named (fight it from three squares out).
return {
    name = "Helm of Terror",
    description = "Foes within 2 of you move 2 fewer spaces.",
    presence = { radius = 2, movement = -2 },
}
