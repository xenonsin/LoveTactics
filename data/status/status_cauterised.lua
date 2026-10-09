-- CAUTERISED: fire on the Lernaean Hydra seals its necks, and no head grows back while it holds (models/lerna.lua).
-- Reviewed 2026-10-09 ("The Crown's Bestiary", slice E): "Fire or Burn on it cauterises: heads stop growing for
-- 2 turns." A cut still takes a head; it simply does not come back as two.
--
-- A debuff, because it is one -- the hydra's bad news. Nothing on its side cleanses, so the window is the fire's.
return {
    name = "Cauterised",
    abbr = "Caut",
    description = "Cauterised: no head grows back.",
    color = { 0.820, 0.420, 0.160 }, -- badge tint (a seared orange)
    duration = 10, -- ~2 turns
    debuff = true,
}
