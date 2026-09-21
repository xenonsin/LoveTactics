-- Demon: the Host.
--
-- THE HOLY LINE FINALLY LIVES SOMEWHERE. docs/bestiary.md calls `kind = "demon"` the one place kind was
-- ever allowed to mean something mechanical -- every demon must go into a fight taking holy damage the
-- harder, because the game's entire holy line is written against it: Smite, Demon Bane ("cuts the
-- damned tenfold"), the Cathedral's shelf and the Priest's reason to exist all pay off here and nowhere
-- else. It was a rule ASSERTED over sixteen blueprints and authored in none of them.
--
-- It is a race, so it is stated once. A body that declares this takes holy the harder because of what
-- it is, rather than because a spec went looking afterwards.
--
-- KEPT NARROW. The -3 here is the floor every demon stands on; the ones whose fiction wants more still
-- carry their own (the Demon Lord's crown, utility_demonic_essence, is -8 and bound, so it never comes
-- off). tests/bestiary_spec.lua measures the finished UNIT rather than the blueprint, which is what
-- lets the line live one layer out like that -- and it goes on measuring the unit, so this file makes
-- the rule cheap to keep rather than replacing the check that keeps it.
--
-- NOT PLAYABLE: a demon does not join the company, and `revivable = false` on the blueprints says the
-- other half of the same thing -- they do not come back.
return {
    name = "Demon",
    description = "The Host. They burn what they touch, and they do not come back.",
    kind = "demon",
    playable = false,
    resist = { holy = -3 },
}
