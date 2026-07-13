-- Rogue vendor. Its quest line is theft and quiet murder, and ends facing Greed.
return {
    name = "The Undercroft",
    class = "rogue",
    sprite = "assets/vendors/undercroft.png", -- shopkeeper portrait; falls back to a placeholder
    description = "No sign, no door you'd notice. Everything inside belonged to someone else.",
    ranks = { 0, 40, 100, 200 },
    rankNames = { "Cutpurse", "Prowler", "Shadow", "Guildmaster" },
    sin = "greed",
}
