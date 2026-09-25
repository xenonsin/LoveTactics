-- UNDER THE BANNER: a dwarf standing in the Banner of the Mountain's ground (data/hazards/
-- hazard_mountain_banner.lua). Zone-bound, as Inspiration is: it lasts while the dwarf stands in the
-- banner's reach and the banner stands.
return {
    name = "Under the Banner",
    abbr = "Bnr",
    description = "Under the Mountain's banner: increase damage while it stands near.",
    color = { 0.600, 0.470, 0.300 }, -- badge tint (old bronze)
    duration = 8,
    statBonus = { damage = 2 },
}
