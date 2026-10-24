-- The Demon Champion's horn: what the avatar lays on the guild's counter as proof of the kill.
--
-- Not forging stock -- no class, never billed at the Forge -- and not a seal: it buys nothing on its
-- own. It is the OBJECT the recommendation is made over (conversation_prologue_arrival): taken off the
-- Champion when it falls on floor one (states/prologue.lua's runOverworld, on the road opening) and
-- handed over as that scene closes (states/hub.lua). Carried for exactly the walk between, so a player
-- who opens the bag on the way out sees what they are bringing home.
return {
    name = "Champion's Horn",
    description = "Broken from the Demon Champion on floor one. Proof, for anyone who needs it.",
    sprite = "assets/materials/champion_horn.png",
    tier = 3,
    proof = true, -- not forging stock: nothing at the Forge bills it
}
