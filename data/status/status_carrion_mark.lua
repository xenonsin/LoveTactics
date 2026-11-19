-- Carrion Mark: a foe picked out for the kill (the hunter's Carrion Mark). On its own it does nothing --
-- whoever laid it is QUICKENED the moment the marked body falls, by anybody's hand, while the mark holds
-- (Engine.onFell, models/engine.lua). The Reaper's tempo, priced in planning the kill order.
return {
    name = "Carrion Mark",
    abbr = "Crn",
    description = "Marked for the kill: when it falls, whoever marked it is Quickened.",
    color = { 0.55, 0.42, 0.30 }, -- badge tint (carrion)
    duration = 10, -- ~2 turns
    debuff = true,
}
