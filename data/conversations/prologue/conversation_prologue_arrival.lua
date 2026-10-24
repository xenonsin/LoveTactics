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
-- says "The Rift", and data/buildings/the_gate.lua's `name` must keep agreeing with what she calls it
-- (the card reads "Rift" -- plaza cards drop the article, her line keeps it).
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
-- AND IT ENDS ON HER WOUND (2026-10-01). Rowan was felled by the Champion (models/combat.lua's
-- Combat.spendScriptedFell) and walks into the city carrying Blood Loss, and the city now HOLDS the
-- company to seeing to it: every plaza card but the Cathedral refuses until she is mended
-- (states/hub.lua's openPanel), and the Cathedral's desk offers only the mending (models/counter.lua).
-- A rail with nobody saying why is a locked screen, so the last thing she says before the bubble goes
-- up is that she is hurt and needs a priest. The two lines are PLACEHOLDERS; the words are the
-- author's. Name the CATHEDRAL (the card's `name`), not "the Ward" -- that is the room behind its desk.
--
-- The city's ECONOMIC dependence on the Rift is deliberately not here -- no market stocked out of it,
-- no treasury. It is a hole that has to be kept clear, and the reason to go down is that it pays.
-- AND IT IS WHERE THE AVATAR GETS A CLASS (2026-10-23), AT THE GUILD'S COUNTER. Three in the scene: the
-- guild attendant (data/vendors/guild.lua -- the same face drawn behind the counter at the Gate), the
-- avatar and Rowan. The avatar lays the Demon Champion's horn on the counter as proof of the kill
-- (data/materials/material_champion_horn.lua, carried up from floor one and taken here by
-- states/hub.lua), Rowan stands as the guild's WITNESS that the avatar took it down, and the guild takes
-- her word for one class: as the scene closes the Armory's Roll opens on the avatar and is HELD OPEN
-- until a root is picked, free (states/hub.lua's openFirstPick, Class.pickOwed). Nothing in Act 0
-- counted toward a class, so this is the avatar's first. It ends on the attendant's line because the
-- pick follows it on the next frame.
--
-- Tags 1, 3, 4 and 6-11 are PLACEHOLDERS, and so is the order. 1, 3 and 4 were the author's street
-- lines (rift raff; the guild failing to clear the Rift), retired when the scene moved to the guild's
-- own counter; 2 and 5 are the author's and stand.
return {
    title = "After the Breach",
    cast  = { "guild", "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- Rowan, at the guild's counter: the job on floor one is done.", tag = 1 },
        { "character_rowan", "The champion wasn't in the report but you did well to take it down.", tag = 2 },
        { "character_rowan", "PLACEHOLDER -- why a champion was on floor one at all, said in front of the guild.", tag = 3 },
        { "character_rowan", "PLACEHOLDER -- what that means for the city above the Rift.", tag = 4 },
        { "character_rowan", "Let's collect our pay and see what work The Rift is offering, {name}.", tag = 5 },
        { "guild", "PLACEHOLDER -- the attendant asks what the company brings up.", tag = 10 },
        { "character_avatar", "PLACEHOLDER -- the avatar lays the Demon Champion's horn on the counter.", tag = 11 },
        { "character_rowan", "PLACEHOLDER -- she stands as the guild's witness: the avatar took it down.", tag = 8 },
        { "character_rowan", "PLACEHOLDER -- she says the Champion's blow is still on her, and she is hurt.", tag = 6 },
        { "character_rowan", "PLACEHOLDER -- and that she needs a priest at the Cathedral before anything else.", tag = 7 },
        { "guild", "PLACEHOLDER -- the attendant takes the horn and her word, and asks what class the avatar will be entered as.", tag = 9 },
    },
}
