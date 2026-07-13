-- Priest vendor. Its quest line hunts the corrupted and ends facing Lust.
return {
    name = "The Cathedral",
    class = "priest",
    sprite = "assets/vendors/cathedral.png", -- shopkeeper portrait; falls back to a placeholder
    description = "Cold stone and colder certainty. The faithful arm those who purge.",
    ranks = { 0, 40, 100, 200 },
    rankNames = { "Penitent", "Acolyte", "Confessor", "Saint" },
    sin = "lust",
}
