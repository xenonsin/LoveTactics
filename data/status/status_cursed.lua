-- CURSED: the thing the worms leave in the ground, and the one status that both eats a body and
-- refuses to let it be mended.
--
-- Granted by data/hazards/hazard_curse.lua -- the Unseeing's floor, what his clan leaves where it dies,
-- and what utility_the_wake lays behind a player who took it off him.
--
-- IT IS ZONE-BOUND, AND THAT IS THE COUNTERPLAY. It declares no `lingers`, so per models/hazard.lua's
-- rule 1 it is stamped with the granting zone's id as its `source`: it does not age, it holds exactly as
-- long as a live curse tile sits under the body, and Hazard.reap ends it the instant one does not. Step
-- off and both halves stop at once -- the damage and the refusal.
--
-- A ZONE-BOUND STATUS STILL TICKS, which is the fact this whole status depends on and is easy to read
-- the wrong way. Status.tick's own note says a zone-bound status "does not age at all", and it means the
-- DURATION: Status.tick skips the countdown but still fires `onTick`, and hands a sourced status the
-- full elapsed slice rather than clamping it to a remaining it does not have. So ground can bleed a body
-- for as long as it stands there without ever needing a duration on the badge.
--
-- WHY IT IS NOT status_unclosing_wound, which also blocks healing and was what this ground granted
-- first. That one is a BLOW's status -- an ordinary cleansable debuff on the physical school, resisted
-- by defense, ten ticks, carried by weapon_unclosing_edge and weapon_unclosing_spear. This is a place.
-- Reaching for the same id would have meant either a curse you can Cure while standing in it (which
-- reads as the ground being broken) or teaching the blow to burn, which would quietly have made three
-- other weapons deal damage over time. Two words, because they are two mechanics that happen to share
-- half an effect.
--
-- THREE A TURN, against Burn's four and Poison's three. It sits with the poison rather than the fire on
-- purpose: the zone it comes from lasts 25 ticks where a Fire lasts 15, it costs nothing to lay, and it
-- is doing a second job the other two are not. What makes the ground dangerous is the pair, not the
-- number -- a body standing in this is losing health it has no way to get back.
return {
    name = "Cursed",
    abbr = "Crs",
    description = "Cursed: losing health, and nothing can heal it.",
    color = { 0.404, 0.286, 0.451 }, -- badge tint (bruised violet)
    magnitude = 3,   -- damage per turn's worth of ticks (spread over the clock by ctx.accrue)
    tags = { "dark" },
    debuff = true,
    blocksHealing = true,
    -- NO `duration` THAT MATTERS and no `lingers`: the zone owns both ends of this. A figure is still
    -- declared because Status.apply wants one for a status granted outside a zone (a test stand, a
    -- future item), and it should be short enough that such a grant is not secretly the better one.
    duration = 10,
    onTick = function(ctx)
        -- Quoted PER TURN and spread over the ticks a turn is worth, exactly as Burn and Poison are
        -- (ctx.accrue). The alternative -- damage per tick -- makes the same number mean something
        -- different to a fast body than to a slow one, which is not what "three a turn" should mean.
        local n = ctx.accrue(ctx.magnitude)
        if n > 0 then ctx.damage(ctx.unit, n, { "dark" }) end
    end,
}
