-- THE TITHE-TAKER: something takes a cut of everything the bearer does.
--
-- `manaSurcharge` and `staminaSurcharge` together, so it reaches every action in the game rather than
-- half of them -- a caster and a swordsman are hexed equally, which none of the other rule curses manage.
--
-- THE TRAP IS ALREADY BUILT AND IS THE REASON THIS IS A CURSE AT ALL. Combat's spend path applies a
-- surcharge AFTER affordability has been checked, and its own comment says why: "a company that could
-- just afford an action commits to it and then finds the pool emptier than it planned. That is the trade
-- the relic sold." The Overreach and The Quick Draw sell that knowingly. Nobody asked for this one.
--
-- WHICH IS THE WHOLE DIFFERENCE between a trade and a hex, and it is worth saying plainly because the
-- mechanic is identical: an item the player chose is a bargain, and the same rule arriving off a trap is
-- a curse. The catalogue proves the point in both directions.
--
-- THREE APIECE, against costs that run 4 to 16. On a cheap ability that is a heavy tax and on an
-- expensive one it is a rounding error, so the hex quietly pushes a body toward its biggest cast --
-- which is a nudge with a shape rather than a flat penalty, and a nudge in the wrong direction for a
-- skirmisher who lives on cheap actions.
return {
    name = "The Tithe-Taker",
    description = "Every action the bearer takes costs 3 more mana and 3 more stamina.",
    binds = true,
    depth = 8,
    fee = 250,
    rules = { manaSurcharge = 3, staminaSurcharge = 3 },
}
