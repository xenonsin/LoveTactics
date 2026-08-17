-- Encounter blueprint. THE SINK: a hole in the floor you do not see until you are through it.
--
-- Wizardry's chute, and the reason it is the most feared square in the game: it drops you a level. Not
-- to the stairs of the level below, not past a fight you were dreading -- into the middle of somewhere
-- deeper than you had agreed to go, at whatever health you happened to be carrying, with the way back up
-- now a floor away. Every calculation about how far from the exit you were willing to be is wrong at
-- once, and that is the whole of the horror.
--
-- IT SKIPS THE STAIR, and skipping the stair is not a mercy. The guardian on the floor you fell out of
-- is still standing (nothing was beaten), so the circle is not credited and its general's boon is not
-- paid -- a company that sinks its way down arrives deeper, poorer, and with a fight it will have to
-- come back up for. The temptation to treat a sink as a shortcut is the trap, and the accounting is what
-- springs it.
--
-- Resolved in states/game.lua, which is where the floor stack lives. At the bottom of the descent there
-- is nothing under you to fall into, so it resolves as bad footing and nothing else -- a floor that
-- could drop you past the Hollow Crown would end a run by accident.
--
-- `weight = 0`: authored-only. See encounter_dark.lua.
return {
    name = "The Sink",
    kind = "sink",
    weight = 0,
    minDay = 1,
}
