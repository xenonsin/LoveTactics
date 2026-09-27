-- THE HORN: what an oni IS, granted by its race (data/races/oni.lua) into the first free cell of every oni ever
-- minted, the way a goblin's Blood Feud is. Reviewed 2026-09-26/27 ("The Oni of Wrath").
--
--   HORN OUT         below half health, or when an oni of its side is felled: +3 Damage, +1 Speed, heals 10% a
--                    turn, and goes for whoever did it (trait_the_horn, status_horn_out, AI.preempt)
--   SNAPPED          a critical hit breaks the horn: no Horn Out, no casting, and weak to every physical blow
--                    and every spell (status_horn_snapped)
--   THE WITCH'S TAINT  a foe carrying a hex is struck for 25% more and hunted first (trait_witchs_taint)
--
-- The horn carries the +1 physical and the magic defense the review asked for, so the race line stays inside
-- the innate contract (see the race's header). Bound and unstealable: an organ, never kit.
return {
    name = "The Horn",
    description = "Below half health, or when an oni of your side falls: Horn Out. A critical hit snaps the horn.",
    flavor = "Everything an oni is lives in the horn. It is why they never let you near the head.",
    sprite = "assets/items/utility_oni_blood.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    resist = { slash = 1, impact = 1, pierce = 1 },
    bonus = { magicDefense = 2 },
    traits = { "trait_the_horn", "trait_witchs_taint" },
}
