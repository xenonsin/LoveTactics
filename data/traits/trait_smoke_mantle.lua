-- Smoke Mantle: the standing rule of the Ninja's armour of the same name. A bearer who drew no blood on
-- its last turn opens the next one Invisible.
--
-- A flag (Trait.flag) read in Combat.startTurn, which compares the bearer's `hitDealt` tally against
-- the bookmark it left there a turn ago. No new state and no new hook: "did the count move" is the same
-- question as "did I attack", asked of a number the engine already keeps.
--
-- The condition is the whole item, and it is a real cost rather than a formality: a ninja who wants the
-- veil has to give up a turn of damage for it, every time, and the shelf's other pieces (Vanishing
-- Strike, Mirror Image) all end with the ninja hidden anyway. So this is the patient route to the same
-- place -- and it is the one that works when the mana is gone.
--
-- Note it pairs with Mark rather than fighting it: a Marked ninja cannot turn Invisible at all
-- (status_mark's `forbids`), so a hunter who paints the ninja shuts this off until the mark is cleansed.
return {
    name = "Smoke Mantle",
    description = "Draw no blood on a turn and you open the next one Invisible.",
    veilsWhenIdle = true,
}
