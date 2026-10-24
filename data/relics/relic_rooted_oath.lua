-- RARE. Allies cannot move. In exchange every ability reaches further and hits harder, which turns the
-- deployment phase into the entire tactical decision: where you place is where you fight, for the whole
-- battle.
--
-- THE RULE FIRES ONCE. You cannot be rooted twice, so a second copy pays more range and more damage for
-- the rooting already taken -- at three copies the company is a stationary artillery line that
-- out-ranges everything on the board, which is a real answer to a map rather than a bigger number.
--
-- OBJECTIVES THAT CROSS GROUND (reach, escort, escape) are NOT refused: the rule zeroes WALKING only
-- (Combat.moveBudget), so an ability that moves a body -- a blink, a leap, a swap -- still carries it.
-- The card says so in plain words (the author's line, 2026-10-24), and the deploy screen repeats it on
-- an objective fight while the Oath is held (Relic.deployNotice).
return {
    name = "The Rooted Oath",
    -- The damage half is stated on the price line rather than crammed in here, because two magnitudes
    -- in one sentence read as one number the player then has to untangle. `scale` can only resolve one
    -- `%d`, and the reach is the half that changes where you stand.
    blurb = "The company cannot walk. Reach, escort and escape fights need abilities that move. "
        .. "Every ability reaches +%d tiles.",
    tier = "rare", mark = "Ro",
    cost = "No walking at all -- in exchange for +50% damage (+25% per extra copy).",
    scale = { 3, 2 },
    rules = { noMove = true, abilityRange = true, damageMultiplier = true },
    ruleScale = {
        abilityRange = { 3, 2 },      -- +3 range, +2 per further copy
        damageMultiplier = { 1.5, 0.25 }, -- +50%, +25% per further copy
    },
}
