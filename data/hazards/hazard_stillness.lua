-- Stillness: a patch of ground where the hour does not pass. Anything standing in it is Halted -- it
-- may still be walked out of, it may still answer a blow, but it may not ACT.
--
-- Halted rather than Stunned, and the choice carries the whole design. Stun takes the reflexes too, so
-- a stillness built on it would be a large free execution: park it over three enemies and kill them
-- with no answer thrown. Halted takes only the initiative in the plain sense of the word -- the will
-- to act first -- and leaves every parry, thorn and guard standing. So the zone stops a line from
-- WORKING without making it safe to walk into, which is the difference between area denial and a win
-- button. See Status.halted's own comment in models/status.lua, which draws exactly this line.
--
-- It also does not care whose feet are in it. A mage who drops the hour over a melee has stilled their
-- own knight as surely as the enemy's, and the mage's side is usually the one that minds more, because
-- the mage's side chose the moment. Casting it well means casting it where your own people are not.
--
-- Long enough to matter (~3 turns) and expensive enough on the ability that lays it to hurt, because
-- what it really buys is not damage -- it is the enemy's turn order, which is the most valuable thing
-- on this board and the hardest to get any other way.
return {
    name = "Stillness",
    description = "Stilled ground: nothing standing in it may take an action.",
    sprite = "assets/hazards/stillness.png",
    tags = { "arcane" },
    duration = 15,           -- ~3 turns of held time
    disposition = "hostile",
    onEnter = function(ctx)
        -- Halted declares no `lingers`, so this grant is zone-bound: it lifts the instant its bearer
        -- steps clear of the stillness or the stillness itself passes (Hazard.reap). Walking out is
        -- always the answer, and always costs the walk.
        ctx.applyStatus(ctx.unit, "status_halted")
    end,
}
