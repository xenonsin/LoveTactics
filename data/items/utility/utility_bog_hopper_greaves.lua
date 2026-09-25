-- BOG-HOPPER GREAVES: the Giant Toad's legs, made for a person. Every move is a hop of up to three tiles
-- over bodies and rough ground, for 8 stamina a hop -- and the wearer's movement stat stops mattering, so
-- heavy armour, a meal, Cripple and every other thing that shortens a walk stop shortening this one. Root
-- and Stun still hold (Combat.hopReady). Returned on review 2026-09-25 after a first cut: "this item will be
-- very useful for tanks".
--
-- A TANK'S PIECE WITHOUT A RULE SAYING SO. Always on, with no toggle (`moveBehavior.always`), so it is how
-- the wearer moves, not an option they reach for. A knight in plate walks 2 or 3 and hops a reliable 3; a
-- skirmisher who walks 6 LOSES reach wearing these. And it is priced in the pool a tank spends on guarding
-- and on Pull: 18 stamina at 2 a turn buys two hops up front and then about one in four. Unaffordable, the
-- wearer walks as normal -- Blink's fallback -- so the Greaves are never a trap.
--
-- Rift-only, off the toad (the review's first objection was a leap sold at a counter, "too similar to
-- leap" -- weapon_pounce -- and a trophy is not merchandise). The rung is placed rather than graded: the
-- grader reads stats and a moveBehavior carries none, so it would rate this at nothing and deal it at rung
-- 1 (models/grade.lua, the same blind spot an immunity has).
return {
    name = "Bog-Hopper Greaves",
    description = "You move only by hopping: up to 3 tiles over anything, for 8 stamina a hop. Movement "
        .. "penalties no longer slow you.",
    flavor = "Whatever you are wearing, and however much of it, you land where you meant to.",
    sprite = "assets/items/utility_bog_hopper_greaves.png",
    type = "utility",
    tags = { "boots" },
    class = "knight",
    unlockLevel = 3,
    unstocked = true,
    moveBehavior = {
        mode = "teleport",
        always = true,
        movement = 3,
        cost = { stat = "stamina", amount = 8 },
        verb = "hops",
    },
}
