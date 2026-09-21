-- Object: a thing on the board that is not a body.
--
-- A ward driven into the ground, a plank, a cart, a homunculus discard being escorted. This kind has
-- always been rung 0's companion -- "this will never fight" said out loud -- and it takes a race here
-- for the same reason every other kind does: kind is derived from race now, and a field with no source
-- is a field that reads nil.
--
-- It is the one race that is a category error if you look at it straight, and that is fine. A plank has
-- no race; what it has is a row in the table that says so, which is worth more than an absent field
-- nobody can tell from an oversight.
return {
    name = "Object",
    description = "A thing on the board that is not a body. It may be broken; it cannot be killed.",
    kind = "object",
    playable = false,
}
