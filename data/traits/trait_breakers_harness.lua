-- Breaker's Harness: the standing rule of the Vanguard's armour of the same name. A shove that ends
-- against something -- a wall, a body, the edge of the field -- Stuns whatever it slammed.
--
-- Only on a COLLISION, which is the whole design. A shove with room to travel is just displacement, and
-- the knight's shelf already sells plenty of that; what this rewards is aiming. The Vanguard who reads
-- the map and drives a body into the rank behind it gets a stun the same shove would not have bought in
-- open ground, so the mechanic is a question about where the wall is rather than a rider on a button.
--
-- It stacks honestly with the Wedge: a collision under both leaves the victim Sundered AND Stunned,
-- which is a full turn taken and its armour opened, off one shove. That is a lot -- and it costs two of
-- nine grid cells and a correctly-read board to arrange, which is the price the discipline is sold at.
return {
    name = "Breaker's Harness",
    description = "A shove that slams its victim into something Stuns them.",
    stunsOnCollision = true,
}
