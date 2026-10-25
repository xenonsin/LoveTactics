-- RAIN: everyone on the board is Wet, and stays Wet (data/status/status_wet.lua) -- fire lands weaker,
-- lightning and ice harder, and a soaked body carries a charge to the next. Soaked at the bell and
-- re-soaked each turn (models/condition.lua), so a Cure buys one turn dry and no more.
return {
    name = "Rain",
    description = "Everyone is Wet: fire is weaker, lightning and ice are stronger.",
    color = { 0.43, 0.60, 0.85 },
    soak = "status_wet",
}
