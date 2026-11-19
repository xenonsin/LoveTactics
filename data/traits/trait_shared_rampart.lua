-- Shared Rampart: allies standing next to the bearer are covered by its barrier pool once their own has
-- run dry: one amount, spent for whoever is struck (Engine.sharedBarrierFor, read by the pooled
-- barrier's forecast and its soak alike). The Paladin's twist on the knight's Rampart.
return {
    name = "Shared Rampart",
    description = "Your barrier also covers allies next to you.",
    sharesBarrier = true,
}
