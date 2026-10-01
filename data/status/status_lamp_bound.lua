-- LAMP-BOUND: the Wishmaker after her third wish (models/djinn.lua). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- Not Yet's rule (`preventsDeath`: a blow that would fell her leaves her at 1) with the Lamp for a clock instead
-- of a duration: it lasts exactly as long as the Lamp stands, and the Lamp's breaking takes it off
-- (trait_the_lamp). Its own status rather than Not Yet stretched to forever, because the badge has to name the
-- thing the company must break, and a countdown of infinity names nothing.
return {
    name = "Lamp-Bound",
    abbr = "Lamp",
    description = "Cannot be killed while the Lamp stands: any blow leaves it at 1 health.",
    color = { 0.930, 0.760, 0.330 }, -- badge tint (lamplight)
    duration = math.huge,
    hideDuration = true,
    preventsDeath = true,
}
