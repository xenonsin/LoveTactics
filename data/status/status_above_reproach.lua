-- ABOVE REPROACH: the Above Reproach's opening ward (data/items/armor/armor_above_reproach.lua). The first
-- hit of any kind on the bearer is turned aside entirely (a barrier, `negates = "any"`, one charge), and it
-- waits for that hit however long the fight takes.
return {
    name = "Above Reproach",
    abbr = "Abv",
    description = "The next hit of any kind is turned aside entirely.",
    color = { 0.820, 0.655, 0.282 }, -- badge tint (gilt)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    negates = "any",
}
