-- Chilled: frost in the joints of the armour (the alchemist's Rime Draught). On its own it only slows
-- nothing and hurts nothing -- the setup half of a REACTION (docs/engines.md, Reactions). A HAMMER or
-- an AXE blow landing on a chilled body shatters it: the chill is spent and its armour reads 0 for two
-- turns (status_shattered; Engine.afterWound, models/engine.lua).
--
-- The answer to plate that is not raw damage. The alchemist lays it and the heavy weapon spends it, so
-- it is a reason for a knight or a barbarian to stand beside the one throwing the draught.
return {
    name = "Chilled",
    abbr = "Chl",
    description = "Chilled: a hammer or axe blow shatters its armour to 0 for 2 turns.",
    color = { 0.62, 0.84, 0.95 }, -- badge tint (rime)
    fx = { field = true },
    duration = 20, -- ~4 turns
    debuff = true, -- removable by Cure
    lingers = true,
}
