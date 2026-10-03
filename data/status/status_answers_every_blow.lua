-- ANSWERS EVERY BLOW: the Griffin's reflex worn off the Mask of Champions (data/traits/trait_mask_of_champions.lua).
-- Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- Only the badge: the mask's own trait answers (its `counter` rule requires this status), so the hover preview,
-- which reads the same rule, promises the answer only while the mask is worn this way.
return {
    name = "Answers Every Blow",
    abbr = "Ansr",
    description = "Answers Every Blow: bite back at every melee blow taken for half your damage.",
    color = { 0.720, 0.600, 0.420 }, -- badge tint (griffin tawny)
    duration = math.huge,
    hideDuration = true,
}
