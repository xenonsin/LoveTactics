-- THE DULLING: every blow the bearer lands comes off soft.
--
-- `rules.damageMultiplier = 0.75` -- The Unpaid Tithe's 1.5 pointed the other way, on the same term, in
-- the same place. It is the purest thing the rule bag can say against a body: no condition, no
-- counterplay, no clever positioning, a quarter off everything for as long as the piece is carried.
--
-- DELIBERATELY DOES NOT BIND, and that is the design rather than mercy. A binding Dulling would be a
-- trip to the Cathedral and nothing else -- there is no play to make and no reason to think about it. A
-- LOOSE Dulling on a weapon worth carrying is a real question every time the player opens the Armory:
-- this sword still hits harder at three quarters than the clean one does at full, so do I keep it?
-- A question is better content than a queue.
--
-- Which makes it the hex the counting shelf argues with most directly. The Reckoning pays per hex; this
-- one takes a quarter off what it pays. Carrying both is a build that has to be checked rather than
-- assumed, and checking it is the kind of thing this game is for.
return {
    name = "The Dulling",
    description = "Every blow the bearer lands deals a quarter less damage.",
    depth = 6,
    fee = 200,
    rules = { damageMultiplier = 0.75 },
}
