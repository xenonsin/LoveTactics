-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The arrival at the capital, played OVER the hub city on the first visit (states/hub.lua reads the
-- prologue's hubIntro flag). This is the beat that used to be a bare gate-watch exchange on a black
-- prologue backdrop; it now stages against the city the player is looking straight at. Its job is to
-- turn a sudden hub into an arrival: the survivors are processed at the gate, Rowan's plate is
-- recognized, and the guard points the newcomers at the Quest Board -- which the hub then coaches.
--
-- The beat in the middle is the whole point of the rank. The avatar says who they are and it does not
-- land: the guard acknowledges the TOWN and walks straight past the claim into his next routine
-- question. A baron's second child is not a thing anyone disbelieves, it is a thing nobody bothers to
-- check, and there is nothing left to check it with anyway: a small holding's seal and papers lived in
-- its keep, and the keep burned in a night with everyone in it.
-- Then the plate does land. The only credential in this party is Rowan's, and the party gets through
-- the gate on the Order's name rather than the avatar's.
return {
    title = "The Capital",
    cast  = { { id = "townsfolk", name = "Townsfolk" }, { id = "guard", name = "City Guard" }, "character_rowan", "character_avatar" },

    script = {
        { "character_avatar", "There it is. Walls still standing, gates still shut. The capital.", tag = 1 },
        { "character_rowan", "The Bastion holds this wall. If anywhere is still holding, {name}, it is behind these stones.", tag = 2 },
        { "townsfolk", "More of them. Third column through the gate since morning. Where are we meant to put them all?", tag = 3 },
        { "townsfolk", "Not under my roof, that's certain. Barely bread enough for the mouths already inside.", tag = 4 },
        { "guard", "You there. Off the road, with the others. Nobody passes until they're processed. Names, and where you've run from.", tag = 5 },
        { "character_avatar", "I am the baron of Bellmere's child. The town burned four nights ago.", tag = 14 },
        { "guard", "Bellmere. That's the whole eastern line gone, then.", tag = 15 },
        { "guard", "Papers, a token, a seal, anything to say who you are. No? Then you'll wait like the rest of them until I say oth--", tag = 6 },
        { "guard", "...That plate. That's Bastion steel. You're a sworn knight of the Order?", tag = 7 },
        { "character_rowan", "I held the eastern wall. The wall is ash now. I brought out who I could.", tag = 8 },
        { "guard", "Forgive me, ser. We don't see many of the Order come through on foot these days. Pass. You, and the ones at your back.", tag = 9 },
        { "guard", "It's been like this for weeks. The demons push, a village burns, and everyone still breathing runs for the capital. The city's fit to burst, work's gone dry, and food with it.", tag = 10 },
        { "guard", "But coin still moves for those who can hold a blade. Register with the Adventurers' Guild. The quest board takes anyone who'll take a contract. Pays a good deal better than queuing for bread.", tag = 11 },
        { "character_avatar", "Work that pays. That, we can do.", tag = 12 },
        { "character_rowan", "The board, then. We'll want coin before we want anything else.", tag = 13 },
    },
}
