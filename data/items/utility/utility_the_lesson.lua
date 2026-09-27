-- THE LESSON: the Oni Swordmaster's organ. Approved 2026-09-26 ("The Oni of Wrath"): "every oni within 2 of it
-- gains +10% crit."
--
-- Asked at blow time off the trait's flag (Combat's crit roll reads Trait.flag(..., "teachesCrit") on the
-- striker's allies). A critical hit is what snaps a horn, so the lesson cuts both ways on a board with oni on
-- both sides of it. Bound and unstealable.
return {
    name = "The Lesson",
    description = "Every oni of your side within 2 has 10% more critical chance.",
    flavor = "It has taught a thousand students one thing: the second cut is for people who missed.",
    sprite = "assets/items/utility_the_lesson.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_lesson" },
}
