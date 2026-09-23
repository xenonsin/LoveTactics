-- On the Web: a Silkfoot body standing on a strand (data/hazards/hazard_web.lua). The web is the spiders'
-- home ground, and this is what makes it one: every step and every action costs a quarter less time on
-- the timeline (`costMultiplier`, the knob Haste turns to 0.5), so a spider on its web comes round
-- again sooner -- it covers more ground setting off from a strand (+1 movement, read into the walk's
-- budget when it sets off, so the bonus is spent from web and lost the moment it leaves) -- and its
-- footing is sure, which is two points of speed toward Avoid.
--
-- ZONE-BOUND (no `lingers`): stamped with the web as its source, it lifts the instant the body steps
-- clear or the strand is burned away (Hazard.reap). Pulling a spider off its web, or burning the web out
-- from under it, is how you slow it down.
return {
    name = "On the Web",
    abbr = "Web",
    description = "On its own web: +1 movement, every step and action takes less time, and it is quicker to dodge.",
    color = { 0.86, 0.87, 0.82 }, -- badge tint (silk)
    duration = 10,
    costMultiplier = 0.75,
    statBonus = { speed = 2, movement = 1 },
}
