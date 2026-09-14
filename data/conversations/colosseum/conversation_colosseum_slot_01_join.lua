-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Saber catches the party on the road out of the arena and asks in (the debut's followUp leg,
-- data/quests/colosseum/quest_colosseum_slot_01.lua). The held join banner drains onto the end of
-- this scene, so it is the last thing the player reads here (tests/arena_aftermath_spec.lua).
--
-- WHAT THIS SCENE NO LONGER SAYS. It used to spend lines on her rented house name, on the crowd, and
-- on naming the patron under the sand as something that has eaten better fighters than her. The
-- reckoning is now planted in one plain line and nothing else here carries it; the bout's own opening
-- scene, which named her tell, is gone entirely.
return {
    title = "Past the Gate",
    cast  = { "character_avatar", "character_rowan", "character_saber" },

    script = {
        { "character_rowan", "Someone is following us, {name}. It is her.", tag = 10 },
        { "character_saber", "Easy, knight. If I meant harm I would not walk this loud.", tag = 11 },
        { "character_saber", "Saber. That is the name on the card and it will do.", tag = 12 },
        { "character_saber", "I open every bout the same way. Nobody has read it in years. You did.", tag = 13 },
        { "character_saber", "That was the best fight I have had in a long time.", tag = 14 },
        { "character_saber", "There is something under this arena I cannot beat alone. You have no house and no handler. Neither do I.", tag = 15 },
        { "character_saber", "Take me with you.", tag = 16 },
        { "character_rowan", "She put me on my back in front of a full crowd, {name}. I would rather have her beside us.", tag = 17 },
        { "character_saber", "Then it is settled. Lead on.", tag = 18 },
    },
}
