-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE LINES BELOW ARE PLACEHOLDERS. They are here so the beat RUNS, not so it reads. Every one of
-- them is to be replaced before this ships -- see the brief underneath.
-- ============================================================================
--
-- WHERE THIS SITS. The first time the player walks into the WARD (data/buildings/the_ward.lua), which
-- is a card that arrives on the plaza the first time anybody is carried up broken -- Rowan, off the
-- Demon Champion at the end of Act 0. So the player opens this door holding exactly one wound, on the
-- body they have fought beside since the first street, and Xin is who is standing inside.
--
-- SHE JOINS FROM IT. `grants` on the blueprint recruits her as the scene opens, so the party banner
-- folds onto the end of these lines (states/hub.lua's launchVendor). She is the only companion in the
-- game met above ground.
--
-- IT USED TO BE A PROLOGUE BEAT and the move is the point. A Cathedral scene stood between the last
-- fight and the city, because reaching the city SET EVERY BONE FOR FREE (Wound.clear in hub.enter) --
-- so the only place a wound could be talked about was a moment wedged in before the city existed, and
-- the scene had to carry the whole mechanic in four lines because there was no room that could. There
-- is a room now. The lesson is taught where its answer lives.
--
-- THE THREE JOBS THIS SCENE DOES, in the order they matter:
--
--   1. IT MAKES THE WOUND A PERSON. Rowan is felled by script at the Champion's last stage
--      (models/combat.lua's Combat.spendScriptedFell) and the ledger records it (states/game.lua's
--      inflictWounds). So the first wound in the game is one the player WATCHED land on somebody, not
--      a bar that got shorter. This scene is what collects on that.
--
--   2. IT TEACHES THE TWO WAYS OUT, and they are the room's whole design: resting is free and costs
--      descents, paying costs gold and costs nothing else. Xin is the one who can say that without
--      it reading as a menu, because she is the person who would be doing the resting or the setting.
--      The player is about to be shown both rows; what the scene owes them is WHY there are two.
--
--   3. IT INTRODUCES XIN, and gives her a reason to come that is not a dice roll. A healer who joins
--      because somebody in front of her is hurt is the same recruit with a motive -- and her old
--      underground scene pair (conversation_cathedral_errand_found / _asked) is what this replaces.
--      Its best line is worth lifting almost whole: *"I carry no blade and I cannot end him. Ask me in
--      and I will keep all of you standing while you do."*
--
-- WHAT IT MUST NOT SAY: that healing is something you buy. The free path is the whole legality of this
-- building (models/wound.lua's ward block -- two earlier versions were deleted for charging at the
-- door), and a scene that frames the Ward as a shop teaches the opposite of what the room does. Gold
-- buys the bone set TODAY. It never buys the bone set at all.
--
-- WHOSE VOICE. Xin carries it -- her room, her introduction. Rowan is present and hurt; whether she
-- speaks is an authoring call, though "the wall that holds its post" being unable to stand is the whole
-- image and she is characterized by minding that more than the injury. The avatar is silent for the
-- prologue and there is no reason to change that on the first morning after it.
return {
    title = "The Inn",
    cast  = { "character_xin", "character_rowan", "character_avatar" },

    script = {
        -- 1. She takes Rowan's weight without being asked. The room states itself by what she does.
        -- 2. THE TWO WAYS OUT, and why there are two: time mends it, and she can mend it faster.
        --    Never "the price is", because the free path is the one this room is built on.
        -- 3. Rowan, who minds being carried more than she minds the wound.
        -- 4. THE JOIN -- she asks to come, and says what she is for. The banner folds onto this line.
        { "character_xin", "PLACEHOLDER -- she takes Rowan's weight without being asked.", tag = 1 },
        { "character_xin", "PLACEHOLDER -- time sets a bone; she can set it sooner.", tag = 2 },
        { "character_rowan", "PLACEHOLDER -- she minds being carried more than she minds the wound.", tag = 3 },
        { "character_xin", "PLACEHOLDER -- she asks to come, and says what she is for.", tag = 4 },
    },
}
