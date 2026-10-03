-- PETRIFIED: three Stone (data/status/status_stone.lua) -- the body is stone for 2 turns. It cannot act, cannot
-- move and cannot answer, and a blow on it lands at half: stone is hard to hurt, which is the trade a company
-- makes when it lets one of its own be turned. A debuff, so a Cure brings it back early.
--
-- Medusa's garden wears the same status (models/gorgon.lua): her three statues of past challengers are Petrified
-- and held so, until her half health cracks them open.
return {
    name = "Petrified",
    abbr = "Ptr",
    description = "Turned to stone: cannot act or move, and takes half damage.",
    color = { 0.55, 0.55, 0.52 }, -- badge tint (grey stone)
    duration = 10, -- 2 turns at Status.TICKS_PER_TURN
    debuff = true,
    disablesActions = true,
    blocksMove = true,
    blocksForcedMove = true,
    disablesReactions = true,
    interruptsChannel = true,
    damageTakenScale = 0.5,
}
