-- Giant's Vigour: borrowed muscle. A flat lift to Damage for a long window, drunk out of a bottle
-- rather than earned (data/items/consumable/consumable_elixir_of_the_giant.lua).
--
-- Mechanically it is Blessing's poorer, longer cousin, and the difference is the point of the whole
-- elixir shelf. Blessing (data/status/status_blessing.lua) lifts Damage AND Magic Damage, is cast by a
-- priest on whoever needs it, and costs that priest a turn in the middle of the fight. This lifts one
-- of the two, is drunk by the person holding it, and costs a turn as well -- but it lasts more than
-- twice as long and the party never had to bring a priest. Envy's arithmetic, exactly as the Powder
-- Keg states it: I need not be strong where I can drink something that was.
--
-- A BUFF, so Cure leaves it be. It stacks with Blessing rather than replacing it -- two different
-- statuses, two entries in flatStat's sum -- which is what makes a blessed, elixir-drunk fighter the
-- alchemist's actual argument for a seat in the party.
return {
    name = "Giant's Vigour",
    abbr = "Gnt",
    description = "Borrowed strength: raised Damage.",
    color = { 0.78, 0.45, 0.28 }, -- badge tint (ox-blood and rust)
    duration = 45, -- ~9 turns at Status.TICKS_PER_TURN: most of a fight, which is what you paid for
    statBonus = { damage = 10 },
}
