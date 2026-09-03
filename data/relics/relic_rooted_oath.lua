-- RARE. Allies cannot move. In exchange every ability reaches further and hits harder, which turns the
-- deployment phase into the entire tactical decision: where you place is where you fight, for the whole
-- battle.
--
-- THE RULE FIRES ONCE. You cannot be rooted twice, so a second copy pays more range and more damage for
-- the rooting already taken -- at three copies the company is a stationary artillery line that
-- out-ranges everything on the board, which is a real answer to a map rather than a bigger number.
--
-- WORTH CHECKING BEFORE THIS SHIPS: objectives that require a body to CROSS ground (escorts, control
-- points) assume movement exists. A rooted company cannot satisfy them, and the honest answer is
-- probably that the relic is refused on those maps rather than that it quietly loses.
return {
    name = "The Rooted Oath",
    -- The damage half is stated on the price line rather than crammed in here, because two magnitudes
    -- in one sentence read as one number the player then has to untangle. `scale` can only resolve one
    -- `%d`, and the reach is the half that changes where you stand.
    blurb = "The company cannot move. Every ability reaches +%d tiles.",
    tier = "rare", mark = "Ro",
    cost = "No movement at all -- in exchange for +50% damage (+25% per extra copy).",
    scale = { 3, 2 },
    rules = { noMove = true, abilityRange = true, damageMultiplier = true },
    ruleScale = {
        abilityRange = { 3, 2 },      -- +3 range, +2 per further copy
        damageMultiplier = { 1.5, 0.25 }, -- +50%, +25% per further copy
    },
}
