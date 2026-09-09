-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- This header survives a re-stamp: the tool reads the leading run of `--` lines back off disk and
-- re-emits it (tools/extract_strings.lua, `headerLines`). A comment further DOWN the file does not.
--
-- Played when the overworld map first appears (the sweep's `opening` in states/prologue.lua's
-- FLIGHT_QUEST). Staged as an ORDINARY scene, like the beats either side of it; the compact
-- `overScene` staging is kept for a GUIDED fight's opening, where the board is being read tile by
-- tile (conversation_prologue_village.lua).
--
-- IT IS THE BEAT AFTER THE FIRST FIGHT AND THE BEAT BEFORE THE MAP AT ONCE. `conversation_prologue_flee`
-- ("First Job") used to stand between the two -- a scene beat of its own in states/prologue.lua,
-- played over a plain backdrop -- and its lines are the ones below: it is DELETED and its contents
-- moved here. What that buys is one less screen between the first fight and the first map, and a
-- first-map scene that says what the map is FOR while the player is looking straight at it.
--
-- SO IT CARRIES THE JOIN BANNER NOW. "[Rowan has joined your Party]" is queued by her recruit before
-- the first fight and held through it (the fight's own opening plays with `deferJoins`, states/battle.lua
-- -- an over-the-board scene refuses the banner). The scene that folds it on is simply the next full
-- one, which used to be "First Job" and is now this: states/game.lua plays a quest's `opening` with no
-- `deferJoins`, so Conversation.drainJoins appends it here. Nothing had to be wired for that, and
-- nothing may quietly add `deferJoins` to that call without moving the banner somewhere else.
--
-- WHAT THE SCENE IS FOR, in one line each: the fight in the street is won, the job is not over, and
-- the errand the map is about to hand over is the rest of the city -- what is still loose in it, and
-- who is still in it. The player's first overworld arrives with no explanation at all (markers, fog, a
-- route), and this is what turns a screen of icons into an errand.
--
-- WHAT THE OLD RUINS SCENE SPENT ITS SEVEN LINES ON, all of it cut with the re-premise and said
-- nowhere now: a valley of smoke seen from a hillside, Bellmere gone behind them, that the party's was
-- not the only field that opened -- the first statement in the game that rifts are a condition of the
-- world rather than one bad job -- and the count under it, NINE CHARTERS WORK THESE SHIRES AND THERE IS
-- MORE SMOKE THAN NINE, which was the only place in Act 0 that said how big the trade is. Act 0 no
-- longer leaves the city, so the valley cannot be looked at from here; whatever still needs saying has
-- to be said inside the walls.
return {
    title = "First Job",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Not too bad for your first job, but there's no time to rest.", tag = 1 },
        { "character_rowan", "Let's move to clear out the remaining demons and find survivors.", tag = 2 },
    },
}
