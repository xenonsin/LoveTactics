-- TOAD LEGS: how the Giant Toad moves, which is never by walking. Every move is a hop of up to three tiles
-- that ignores bodies, terrain and its own movement stat (Combat.hopReady -- Blink's teleport, always on),
-- and it costs a lot of stamina. Settled on review 2026-09-25: "it can have 0 movement and still move",
-- "have hop cost a lot of stamina to balance".
--
-- WHICH IS WHAT KEEPS A FULL TOAD DANGEROUS. A meal costs a movement point, and this body has none to lose:
-- the hop reads its own reach off this item. What the hop DOES cost is stamina, from the same pool Leaping
-- Crash (12) spends, so most turns the toad either hops or crashes, and a toad that can pay for neither sits
-- where it is and spits. Root still holds it (Combat.hopReady refuses a rooted body).
return {
    name = "Toad Legs",
    description = "Moves only by hopping: up to 3 tiles over anything, for 8 stamina a hop.",
    flavor = "It does not walk anywhere. It is simply somewhere else now.",
    sprite = "assets/items/utility_toad_legs.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    moveBehavior = {
        mode = "teleport",
        always = true,
        movement = 3,
        cost = { stat = "stamina", amount = 8 },
        verb = "hops",
    },
}
