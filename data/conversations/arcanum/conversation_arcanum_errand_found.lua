-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE SPOKEN LINES BELOW ARE PLACEHOLDERS. The structure, the beats and what each line has to
-- accomplish are settled; the words are the author's. See the brief on each.
-- ============================================================================
--
-- REWRITTEN 2026-09-16 FOR THE DISTANCE RUN. What stood here was written when Gyeom was one of six
-- bodies the roll could deal on any floor of any descent, and it was about a flooded library the rift
-- had copied, a book inside it, and eleven other diggers already digging. All of that belonged to the
-- campaign premise that is parked, and none of it is what the game is about now: depth is the score,
-- the dungeon is new every descent, and there is no fixed place down there to have copied.
--
-- WHAT THE SCENE STOPPED SAYING, recorded here so a later pass knows it is missing rather than assuming
-- it survives somewhere: that the rift COPIES PLACES from the world above; that this floor is a library;
-- that other parties are underground digging for things; and the book, which was the errand's object.
-- The only other place the copying premise was stated in this house's line was this scene.
--
-- IT IS ALSO NOT A MID-GAME MEETING ANY MORE. Gyeom is the scripted floor-one companion now
-- (models/descent.lua's Descent.SCRIPTED_COMPANION), so this plays on the first floor of the first
-- descent, minutes after Act 0 — it is one of the first things anybody sees underground. The old scene
-- assumed context the player did not have: it never gave her name, her house, or a reason she was down
-- here, it put the only line that establishes WHERE YOU ARE on Rowan behind a `when` guard, and it
-- opened on "there are eleven of them in there" without ever naming what "them" was.
--
-- THE NEW PREMISE: SHE CAME DOWN HERE TO LEARN, AND SOMETHING IS SITTING ON THE FIRST THING SHE FOUND.
-- There are workings in the rift that exist nowhere above it. She walked in alone to read them, got one
-- floor, and found a grimoire with a Grendlemaw sitting on top of it. She cannot take it off by herself and
-- she has counted properly enough to know that rather than guess it. So she asks for help -- and she
-- FIGHTS IT WITH YOU (the objective's `allies`, AI-run), rather than waiting on the step while the
-- company does her errand.
--
-- THAT SHE STANDS IN THE FIGHT IS THE CHARACTER, NOT A CONVENIENCE. A mage who asks for help and then
-- watches is somebody the player carried; a mage who asks for help and takes her place in the line is
-- somebody the player fought beside, which is the only one of those two worth four lines and a party
-- slot. It also means the player SEES her kit before being offered it -- her Ledger pays out after four
-- actions, and a heavy single guardian is exactly the fight where that lands in front of them.
--
-- WHY THIS MOTIVE AND NOT "HOW DEEP CAN I GET". Depth-as-a-score is the PLAYER's reason for being here,
-- and a character who states it is just restating the mode back at them. Hers has to be her own, and
-- "I go down to learn" is a reason only Gyeom would give: she is the mage who showed no gift and got
-- formidable by doing the work, over and over, and still holds she has more to learn
-- (data/characters/character_gyeom.lua -- the model is Fern). The deeper the floor, the more there is on
-- it she has never seen. It also lands her relic without a word of explanation: the Ledger is a book she
-- is always writing and never finishes, and she is down here to fill it.
--
-- THE FOUR JOBS THIS SCENE HAS TO DO, in order, and each line below is assigned one:
--   1. Say who she is, unprompted -- she is a stranger on a step and nobody else will introduce her.
--   2. Say what she came DOWN here for. Not depth, not treasure: the workings that are only down here.
--      This is the line that makes her a person rather than a fourth body.
--   3. Point at the grimoire and the thing on it, as a count rather than a complaint -- she is not
--      discouraged, she is short. This names the objective the player is about to accept.
--   4. Ask -- and the ask is to fight it TOGETHER. She is not asking them to fetch it for her; she says
--      she is coming, and the fight seats her (`allies`). Never a favour owed and never a rescue.
--
-- HER REGISTER, so the lines sound like her and not like a quest-giver: she counts, she gives the number,
-- and she does not soften it. A refusal to be flattered is arithmetic and not modesty -- "I did it
-- properly and it comes out the same every time" was the old scene's best line for exactly this reason.
-- She is not embarrassed to be stuck; being stuck is a measurement like any other.
--
-- WHAT IT MUST NOT DO: explain the rift, the houses, the Arcanum, or anything about a book. She does
-- not know more about this place than the player does -- she got one floor in, same as them. And she
-- must not be humble ABOUT herself out loud: the virtue is buried, never stamped (her name is the word,
-- and nobody in the game says it).
--
-- ROWAN'S LINE IS GONE AND NOTHING CONDITIONAL REPLACES IT. The old scene's only premise line was hers,
-- behind `when = { has = "character_rowan" }`, so benching Rowan deleted the one line that said where
-- the player was standing. Nothing load-bearing may sit behind a guard in a scene that has to work on
-- the first floor of the first descent. If a companion reaction is wanted here later, it goes on top of
-- a scene that already reads without it.
return {
    title = "The Thing on the Book",
    cast  = { "character_avatar", "character_gyeom" },

    -- 1. WHO SHE IS -- her name, unprompted, before she asks for anything.
    -- 2. WHAT SHE CAME FOR -- the workings that are only down here.
    -- 3. THE GRIMOIRE AND THE THING ON IT -- counted, not complained about. Names the objective.
    -- 4. THE ASK -- fight it together. She is coming; she is not sending them.
    script = {
        { "character_gyeom", "PLACEHOLDER -- she gives her name before she asks for anything.", tag = 1 },
        { "character_gyeom", "PLACEHOLDER -- there are things to learn down here that are nowhere else.", tag = 2 },
        { "character_gyeom", "PLACEHOLDER -- a grimoire, and what is sitting on it, measured against one of her.", tag = 3 },
        { "character_gyeom", "PLACEHOLDER -- she asks them to take it with her, and says she is coming.", tag = 4, choices = {
            { "Take it together.", tag = 5, answer = "accept" },
            { "Leave her to it.", tag = 6, answer = "decline" },
        } },
    },
}
