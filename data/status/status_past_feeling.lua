-- PAST FEELING: the badge every one of the Bog-Bound wears all fight (data/traits/trait_past_feeling.lua;
-- "Sloth's Bestiary", 2026-10-04, slice C). The rule is models/sloth_bog.lua's: a blow of this much damage or less
-- does nothing, and anything heavier lands in full.
--
-- THE THRESHOLD IS THE BADGE (`badgeCount`): 8, or 16 within 3 of a Cairn-Keeper. Read the number on the body
-- rather than a tooltip -- it is the one fact a company needs before it chooses who swings.
--
-- Not a debuff and undispellable: it is what the body is, and a Cure that made a mummy feel again would be a
-- strange Cure.
return {
    name = "Past Feeling",
    abbr = "Past",
    description = "Past Feeling: a blow of this much damage or less does nothing.",
    color = { 0.380, 0.330, 0.250 }, -- badge tint (peat)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    badgeCount = true,
    magnitude = 8,
}
