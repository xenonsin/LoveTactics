-- Mage vendor. Its quest line chases forbidden knowledge and ends facing Pride.
return {
    name = "The Arcanum",
    class = "mage",
    sprite = "assets/vendors/arcanum.png", -- shopkeeper portrait; falls back to a placeholder
    description = "A library that has outlived every scholar who swore he could read it safely.",
    ranks = { 0, 40, 100, 200 },
    rankNames = { "Apprentice", "Adept", "Magus", "Archmage" },
    sin = "pride",
}
