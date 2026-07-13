-- Hunter vendor. Its quest line fells sacred beasts and ends facing Gluttony.
return {
    name = "Hunter's Lodge",
    class = "hunter",
    sprite = "assets/vendors/hunters_lodge.png", -- shopkeeper portrait; falls back to a placeholder
    description = "Antlers on every beam. They ask what you killed before they ask your name.",
    ranks = { 0, 40, 100, 200 },
    rankNames = { "Tracker", "Stalker", "Beastslayer", "Grand Hunter" },
    sin = "gluttony",
}
