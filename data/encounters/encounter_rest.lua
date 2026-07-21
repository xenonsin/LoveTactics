-- A rest point: the party makes camp and every resource comes back to full (Player.restore, applied
-- in states/game.lua when this encounter resolves). Placed as the last stop before a hard fight -- on
-- the flight leg it sits right before the Demon Champion (states/prologue.lua), so the mini-boss is
-- fought fresh rather than on whatever was left after the road.
--
-- `kind = "rest"`: a non-combat modal like treasure/town (ui/panels/encounter.lua). `weight = 0`:
-- authored-only, placed via `map.encounters.always`.
return {
    name = "A Moment's Rest",
    kind = "rest",
    weight = 0,
    minPrestige = 1,
}
