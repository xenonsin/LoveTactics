-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE LINES BELOW ARE PLACEHOLDERS. They are here so the beat RUNS, not so it reads. Every one of
-- them is to be replaced before this ships -- see the brief underneath.
-- ============================================================================
--
-- WHERE THIS SITS. On the far side of the PRESS that sets Rowan's bone, the first time anybody walks
-- into the CATHEDRAL (data/buildings/cathedral.lua's `introAfter`) -- a card that arrives on the plaza
-- the first time somebody is carried up broken, which is Rowan off the Demon Champion at the end of
-- Act 0. So the player chose the mending off the desk, was held in the room until they took it
-- (ui/panels/ward.lua's rail), and this is what the press hands to.
--
-- IT PLAYED IN THE DOORWAY FOR A PASS, and the move is the whole of what the scene is now. Announced
-- first, Xin said a bone could be set and then stood there while the player set it off a menu -- the
-- healer whose reason to come is that somebody in front of her is hurt, introduced one beat BEFORE she
-- was any use to them. She is the hands on the press now: the player asks for the bone to be set, and
-- she is who sets it.
--
-- SHE JOINS FROM IT. `grants` on the blueprint recruits her as the scene opens, so the party banner
-- folds onto the end of these lines (models/counter.lua). She is the only companion in the game met
-- above ground.
--
-- IT USED TO BE A PROLOGUE BEAT and the move is the point. A Cathedral scene stood between the last
-- fight and the city, because reaching the city SET EVERY BONE FOR FREE (Injury.clear in hub.enter) --
-- so the only place an injury could be talked about was a moment wedged in before the city existed, and
-- the scene had to carry the whole mechanic in four lines because there was no room that could. There
-- is a room now. The lesson is taught where its answer lives.
--
-- THE THREE JOBS THIS SCENE DOES, in the order they matter:
--
--   1. IT MAKES THE INJURY A PERSON. Rowan is felled by script at the Champion's last stage
--      (models/combat.lua's Combat.spendScriptedFell) and the ledger records it (states/game.lua's
--      inflictInjuries). So the first injury in the game is one the player WATCHED land on somebody, not
--      a bar that got shorter. This scene is what collects on that.
--
--   2. IT IS THE MENDING, AND NOT A LINE ABOUT ONE. The two ways out are taught a beat earlier by the
--      window in the room's doorway (states/hub.lua's teachInjuries), which is a rule and belongs in a
--      window; what this scene owes the player is the thing they just paid for, happening. Xin sets
--      the bone here. Never a line pricing it -- the gold is already spent and the free path is the
--      whole legality of the room (see below).
--
--   3. IT INTRODUCES XIN, and gives her a reason to come that is not a dice roll -- one she has just
--      acted on rather than described. A healer who joins because somebody in front of her is hurt is
--      the same recruit with a motive, and the motive is on screen behind her: the body she has this
--      minute put back together. Her old underground scene pair (conversation_cathedral_errand_found /
--      _asked) is what this replaces, and its best line is worth lifting almost whole: *"I carry no
--      blade and I cannot end him. Ask me in and I will keep all of you standing while you do."*
--
-- WHAT IT MUST NOT SAY: that healing is something you buy. The free path is the whole legality of this
-- building (models/injury.lua's ward block -- two earlier versions were deleted for charging at the
-- door), and a scene that frames the Ward as a shop teaches the opposite of what the room does. Gold
-- buys the bone set TODAY. It never buys the bone set at all.
--
-- WHOSE VOICE. Xin carries it -- her room, her introduction. Rowan is present and hurt; whether she
-- speaks is an authoring call, though "the wall that holds its post" being unable to stand is the whole
-- image and she is characterized by minding that more than the injury. The avatar is silent for the
-- prologue and there is no reason to change that on the first morning after it.
return {
    title = "Inn",
    cast  = { "character_xin", "character_rowan", "character_avatar" },

    script = {
        -- 1. She takes Rowan's weight without being asked. The room states itself by what she does.
        -- 2. THE WORK, not a word about the price of it: the bone goes back, and it is her hands.
        -- 3. Rowan, who minds being carried more than she minds the injury.
        -- 4. THE JOIN -- she asks to come, and says what she is for. The banner folds onto this line.
        { "character_xin", "PLACEHOLDER -- she takes Rowan's weight without being asked.", tag = 1 },
        { "character_xin", "PLACEHOLDER -- the bone goes back, under her hands, now.", tag = 2 },
        { "character_rowan", "PLACEHOLDER -- she minds being carried more than she minds the injury.", tag = 3 },
        { "character_xin", "PLACEHOLDER -- she asks to come, and says what she is for.", tag = 4 },
    },
}
