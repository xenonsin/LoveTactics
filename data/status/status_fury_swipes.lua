-- FURY SWIPES: the wound a bear keeps going back to, and the only thing in the game that COMPOUNDS.
--
-- Every other threat in this bestiary is answered by a fact about the board -- how far away it is, which
-- line you are standing on, what it is about to summon. This one is answered by a fact about TIME: the
-- first blow is ordinary and the fourth is not, so the question it asks is how long you are willing to
-- leave one body standing in front of it. Nothing else here ramps.
--
-- THE MAGNITUDE IS THE STACK COUNT, and the bag below is what ONE stack is worth. `vulnerableScales`
-- (models/status.lua, Status.vulnerability) multiplies the two, which is the whole mechanism -- there is
-- no second number kept anywhere, so the badge, the forecast and the blow all read the same field.
--
-- WHY SLASH. The claws are `slash` (data/items/weapon/weapon_great_claws.lua), and a wound reads as the
-- weapon that opened it. It also sets up the symmetry the fight is built on: a bear is WEAK to slash
-- (character_bear.lua's resist line), so the animal opening you along an edge is the animal an edge
-- opens fastest. Both sides of that fight are racing on the same axis, which is a better shape than two
-- unrelated puzzles stacked on one body.
--
-- ...AND WHY ANYBODY MAY SPEND IT. This is a wound on a BODY, not a private tally between two units, so
-- a swordsman standing next to the bear's victim is swinging into ground the bear prepared. That is
-- deliberate (docs/bestiary.md): it turns a solo passive into the party's own play, and it is what makes
-- leaving the cub alive in the sow's fight genuinely expensive -- the cub's stacks are the mother's to
-- spend. The alternative, a bonus private to the striker, has no seam in this engine and no way to reach
-- the damage forecast; see Status.vulnerability's header for that argument in full.
return {
    name = "Fury Swipes",
    abbr = "Swp",
    description = "Worked open: takes 2 more slashing damage for each stack.",
    color = { 0.639, 0.271, 0.239 }, -- badge tint (opened red -- a wound, not a rage)
    -- ~2 turns at Status.TICKS_PER_TURN. The decay IS the counterplay: break off, body-block, make it
    -- want somebody else, and the ramp resets. A wound that never closed would turn a long fight into
    -- an execution with no way back, which is the failure mode this duration exists to prevent.
    duration = 10,
    debuff = true,          -- removable by Cure: a party CAN buy the ramp back, at the price of a turn
    resistible = "physical",
    magnitude = 1,          -- the opening stack; trait_fury_swipes re-applies at +1 up to its own cap
    hideDuration = true,    -- the stack count is the story, not the clock (as status_enraged does it)
    -- WHAT ONE STACK IS WORTH, and it is priced against the one authored vulnerability in the game:
    -- status_vulnerable_slash is a flat 8 for a whole ability. Four stacks -- trait_fury_swipes' cap --
    -- come to exactly that, so a bear that has spent four consecutive blows on one body has earned what
    -- a spell grants in one, and cannot exceed it. That ceiling is the argument; the 2 falls out of it.
    vulnerable = { slash = 2 },
    vulnerableScales = true, -- the bag above is per-stack (see the header)
}
