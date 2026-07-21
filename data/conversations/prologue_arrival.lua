-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The arrival at the capital, played OVER the hub city on the first visit (states/hub.lua reads the
-- prologue's hubIntro flag). This is the beat that used to be a bare gate-watch exchange on a black
-- prologue backdrop; it now stages against the city the player is looking straight at. Its job is to
-- turn a sudden hub into an arrival: the survivors are processed at the gate, Rowan's plate is
-- recognized, and the guard points the newcomers at the Quest Board -- which the hub then coaches.
return {
    title = "The Capital",
    cast  = {
        { id = "townsfolk", name = "Townsfolk" },
        { id = "guard", name = "City Guard" },
        "character_knight",
        "character_avatar",
    },

    script = {
        { "character_avatar", "There it is. Walls still standing, gates still shut. The capital.", tag = 1 },
        { "character_knight", "The Bastion holds this wall. If anywhere is still holding, {name}, it is behind these stones.", tag = 2 },
        { "townsfolk", "More of them. Third column through the gate since morning -- where are we meant to put them all?", tag = 3 },
        { "townsfolk", "Not under my roof, that's certain. Barely bread enough for the mouths already inside.", tag = 4 },
        { "guard", "You there -- off the road, with the others. Nobody passes until they're processed. Names, and where you've run from.", tag = 5 },
        { "guard", "Papers, a token, a seal, anything to say who you are. No? Then you'll wait like the rest of them until I say oth--", tag = 6 },
        { "guard", "...That plate. That's Bastion steel. You're a sworn knight of the Order?", tag = 7 },
        { "character_knight", "I held the eastern wall. The wall is ash now. I brought out who I could.", tag = 8 },
        { "guard", "Forgive me, ser. We don't see many of the Order come through on foot these days. Pass -- you, and the ones at your back.", tag = 9 },
        { "guard", "It's been like this for weeks. The demons push, a village burns, and everyone still breathing runs for the capital. The city's fit to burst, work's gone dry, and food with it.", tag = 10 },
        { "guard", "But coin still moves for those who can hold a blade. Register with the Adventurers' Guild -- the quest board takes anyone who'll take a contract. Pays a good deal better than queuing for bread.", tag = 11 },
        { "character_avatar", "Work that pays. That, we can do.", tag = 12 },
        { "character_knight", "The board, then. We'll want coin before we want anything else.", tag = 13 },
    },
}
