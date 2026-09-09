-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The first-visit scene, played OVER the hub city (states/hub.lua reads the prologue's hubIntro flag).
-- It is the seam between Act 0 and Act 1, and both stand on the same ground: the breach the party just
-- cleared was in this city's own eastern quarter, so nobody travels anywhere between the two. Rowan
-- closes the job standing in the street, and points at the next one.
--
-- FIVE LINES, ALL ROWAN'S. It is the scene that hands the game over: the fight is finished, the reason
-- it happened is said in one sentence, and the last line names where the work and the coin are -- which
-- is the Rift, the one door the hub's coaching stage will let the player open (states/hub.lua). She
-- says "The Rift", and data/buildings/the_gate.lua's `name` must keep agreeing with what she calls it.
--
-- THE CAUSE IS THE WHOLE PAYLOAD: the guild does not clear the Rift deep enough, so the deep floors
-- get left, and what gathers down there comes up into the streets. The breach the player just fought
-- through is that sentence happening. It is the only place in the game that says why any of this is
-- occurring, and it is what ties Act 0 to the loop it hands over to.
--
-- IT MUST NOT TAKE THE WORD FROM ISELLE: the deep floors get LEFT, never "pruned". The trade's
-- nickname is hers to introduce, at the top of the stair (states/gate.lua).
--
-- WHAT THE REWRITE CUT, so nothing downstream assumes it is still said. This was a nine-line scene
-- with a City Guard and two Townsfolk in it, and all three are gone from the cast:
--
--   * THAT THE WORK PAYS BY THE TRIP, and that no charter covers it -- the escalation from licensed
--     field work to a permanent hole nobody is obliged to go down. Only the coin in the last line
--     survives of that.
--   * "NOT MANY CAN, AND FEWER WILL" -- why the deep floors get left at all, which is the half of the
--     cause the guild line does not state.
--   * THE CREDENTIAL BEAT. A guard clocked Rowan's Bastion plate and took the party seriously on it;
--     the avatar holds no rank and no paper, and that the plate is this company's only standing is a
--     note Act 1 keeps hitting (docs/story.md).
--   * THE STREET ITSELF -- two townsfolk arguing over how many breaches this season, which is what
--     made the cause an argument the city was already having rather than an explanation to the player.
--
-- The city's ECONOMIC dependence on the Rift is deliberately not here -- no market stocked out of it,
-- no treasury. It is a hole that has to be kept clear, and the reason to go down is that it pays.
return {
    title = "After the Breach",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "That's the last of rift raff.", tag = 1 },
        { "character_rowan", "The champion wasn't in the report but you did well to take it down.", tag = 2 },
        { "character_rowan", "This is what happens when the guild fails to clear enough of The Rift.", tag = 3 },
        { "character_rowan", "The deep floors get left alone, and whatever gathers down there comes up here.", tag = 4 },
        { "character_rowan", "Let's collect our pay and see what work The Rift is offering, {name}.", tag = 5 },
    },
}
