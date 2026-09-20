-- THE WITNESS: something is watching the hand that holds it, and the hand knows.
--
-- THE ONE HEX THAT DOES NOT BIND, and the set needs exactly one. Every other curse in this folder
-- answers "pay, or go two trips without it"; this one also answers "or take it off and leave it in the
-- stash" -- a third way out the player finds for themselves. Finding it is what teaches that the BIND
-- on the others is the actual curse rather than a decoration on it.
--
-- SKILL AND LUCK rather than attack and defense, because they are the accuracy pair (docs/accuracy.md:
-- skill raises Hit and Crit, luck raises Avoid and blunts an attacker's crit) and the reading a player
-- takes off a body under this is "I keep missing, and I keep getting opened up" -- which is what being
-- watched ought to feel like. A flat -2 attack would have said nothing except that the number is lower.
return {
    name = "The Witness",
    description = "-3 luck and -2 skill while this piece is carried.",
    depth = 2,
    fee = 100,
    bonus = { skill = -2, luck = -3 },
}
