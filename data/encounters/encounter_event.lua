-- A narrative "Choose..." stop on the overworld: no fight, just a scene with branching options that
-- teach a little of the story and hand out something for the road (see the flight leg's events,
-- data/conversations/flight_event_*.lua). The specific scene is not fixed here -- the route entry
-- that places this encounter names it (`conversation`), so one blueprint seeds every event stop.
--
-- `kind = "event"`: states/game.lua plays `cell.encounter.conversation` when the player steps on it,
-- and the branching dialogue (ui/dialogue.lua) carries the choices; a choice's `effect` applies its
-- outcome through models/story_effect.lua. `weight = 0`: authored-only, placed via `map.encounters.always`.
return {
    name = "A Fork in the Road",
    kind = "event",
    weight = 0,
    minPrestige = 1,
}
