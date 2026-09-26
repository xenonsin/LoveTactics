-- THE DIPPED CAP: the Redcap's drop, picked in round 2 (2026-09-26, "The Goblins of Wrath") over Blood Scent,
-- which sat too close to what the assassin shelf already sells.
--
-- A killing blow makes you Invisible until you next act, and wets the cap (status_dipped): your next strike on a
-- foe below half is a certain critical (Combat.forcesCrit; the landing spends it). Kill, vanish, kill again --
-- the assassin's rhythm, and something the shelf did not have.
return {
    name = "The Dipped Cap",
    description = "A kill makes you Invisible until you act, and your next strike on a foe below half health is a certain critical.",
    flavor = "Dipped, and dipped again. The colour never quite takes, which is the point of doing it.",
    sprite = "assets/items/utility_dipped_cap.png",
    type = "utility",
    tags = { "trinket" },
    class = "assassin",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_dipped_cap" },
}
