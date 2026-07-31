-- Centering Charm: the monk's stance made portable. No active ability -- it swaps the holder's Wait
-- into Gather: end the turn without striking to coil instead, and the next blow you land carries the
-- stored force (the Empowered status, +attack spent on the hit). The offensive twin of the shield's
-- Defend, and priced like it in tempo (speed 3, a cheap stance) rather than in a whole meditated turn
-- the way Focus is. See Combat.waitBehavior / Combat.gather and data/status/status_empowered.lua.
--
-- A monk shelf item and a fist-flavoured one (Empowered raises the DAMAGE stat, which is the fist's),
-- so it reads as the same discipline the Iron/Shadow/Swift/Drunken charms build -- but where those pour
-- flat power into every punch, this one banks a turn to make ONE punch land like three. `power` scales
-- with the forge (Item WAIT_BEHAVIOR_MAGNITUDES), so a deeper charm coils a heavier blow.
return {
    name = "Centering Charm",
    description = "Replaces Wait with Gather: end your turn to coil, so your next landed blow hits far harder.",
    flavor = "A breath held is a blow saved. The Cathedral's fighting monks keep no other secret.",
    sprite = "assets/items/centering_charm.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    discipline = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    price = 220,
    unlockQuests = 4,
    waitBehavior = { kind = "gather", speed = 3, power = { 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 10 } },
}
