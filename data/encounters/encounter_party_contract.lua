-- THE CONTRACT: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Poisoner's coated blade and the Hunter's marks wear one of yours down. When a body drops
-- under half, the Assassin blinks to it, finishes it for certain, and blinks back. Deeper, a Rogue
-- and a Thief add bleeding and theft, and an Inquisitor names the target.
--
-- How you beat it: Keep your wounded topped up or out of reach. The assassin only acts on a wounded
-- body, so nobody under half means he stands idle.
--
-- THE CONTRACT IS ON A STRANGER (the objective pass, 2026-10-21): a Stray Delver walks with you, and it is
-- the body they were paid for. Clear them with the stranger still standing.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_contract",
    name = "The Contract",
    core = { "assassin", "poisoner", "hunter" },
    grow = { "rogue", "thief", "inquisitor" },
    combo = "The Poisoner's coated blade and the Hunter's marks wear one of yours down. When a body drops"
        .. " under half, the Assassin blinks to it, finishes it for certain, and blinks back. Deeper, a"
        .. " Rogue and a Thief add bleeding and theft, and an Inquisitor names the target.",
    counter = "Keep your wounded topped up or out of reach. The assassin only acts on a wounded body, so"
        .. " nobody under half means he stands idle.",
    allies = { "character_stray_delver" },
    objective = { type = "killAll", enemy = "the contract killers", protect = "character_stray_delver" },
})
