-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The `opening` of data/quests/cathedral/quest_cathedral_slot_02.lua, RE-PREMISED with the slot. It
-- was the Cathedral naming Amana its accused and Amana answering the charge; she is a companion three
-- quests earlier now (the padded card's epilogue), so the scene is what it says on the road instead.
--
-- The press-gang is a Colosseum crew working the king's road for bodies to card, and the chief is not
-- ashamed of it: he is doing openly what the cart behind him is doing with a blessing on it, and he
-- says so. That is the whole scene. Amana does not hear it, because she cannot yet.
--
-- KEEP THE CHIEF SINCERE. He is not taunting her about the rite; he does not know there is a rite. He
-- knows both houses come out here for the same reason and that only one of them gets thanked for it,
-- and he is annoyed about the competition, not making a point. The point is the player's to make.
return {
    title = "The Intake Road",
    cast  = { "character_bandit_chief", "character_amana", "character_avatar" },

    script = {
        { "character_bandit_chief", "Far enough. Stand off the cart and nobody on it gets a scratch.", tag = 1 },
        { "character_bandit_chief", "We only want the ones who can stand up. The house is short a card and the road is full.", tag = 2 },
        { "character_amana", "This cart is the Cathedral's. These people came to it on their own feet.", tag = 3 },
        { "character_bandit_chief", "So did ours, sister. We work the same mile you do and we get here first some nights.", tag = 4 },
        { "character_bandit_chief", "Nobody hands you a wagon and a blessing for it, that is the only difference I can find.", tag = 5 },
        { "character_amana", "Then find a better one. Nothing on this road is yours to take.", tag = 6 },
        { "character_avatar", "Nets down. Now.", tag = 7 },
        { "character_bandit_chief", "Take them alive if you can, lads. Dead ones fill nothing.", tag = 8 },
    },
}
