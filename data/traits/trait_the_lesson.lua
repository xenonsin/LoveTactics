-- THE LESSON: the Oni Swordmaster's (utility_the_lesson). Combat.critChance adds `crit` to the chance of any oni
-- striking within `radius` of a teacher of its side.
return {
    name = "The Lesson",
    description = "Every oni of your side within 2 has 10% more critical chance.",
    teachesCrit = true,
    notAReaction = true,
    crit = 10,
    radius = 2,
}
