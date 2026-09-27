-- SURFEIT: healing that had nowhere to go, held as a shield (the Surfeit Heart, data/items/utility/
-- utility_surfeit_heart.lua; the Gorged's drop). Its `magnitude` is the shield's size: what the next blow is paid
-- out of before it reaches the body (Combat.soakIntoSurfeit). Whatever that blow leaves of it is gone with it --
-- the shield lasts until you are hit, not until it is used up. Topped up by more healing past full, to the cap the
-- Heart sets (Combat.bankSurfeit).
return {
    name = "Surfeit",
    abbr = "Surf",
    description = "Shielded: the next blow is paid out of this first. Any hit breaks it.",
    color = { 0.780, 0.180, 0.260 }, -- badge tint (a heart's red)
    duration = math.huge,            -- until the next hit; nothing counts it down
    hideDuration = true,
    magnitude = 0,
}
