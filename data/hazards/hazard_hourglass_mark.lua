-- HOURGLASS MARK: where the Sandman reforms when a foe ends its turn beside him (Run Through the Glass,
-- models/sandman.lua; "Sloth's Bestiary", slice G). The counter the review asked for: the mark is shown. It is
-- laid across the board from him and moved after every run.
--
-- It does nothing to anybody. NEUTRAL, so no planner walks toward it or away from it -- a body standing on it only
-- puts him down beside it instead.
return {
    name = "Hourglass Mark",
    description = "The Sandman reforms here when a foe ends its turn beside him.",
    tags = { "earth" },
    duration = 9999, -- moved by a run, never by the clock
    disposition = "neutral",
}
