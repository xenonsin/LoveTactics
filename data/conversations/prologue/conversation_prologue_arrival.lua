-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The arrival at the capital, played OVER the hub city on the first visit (states/hub.lua reads the
-- prologue's hubIntro flag). Its job is to turn a sudden hub into an arrival: the survivors are
-- processed at the gate, Rowan's plate is recognized, and the guard points them at the Rift.
--
-- THE CHARTER BEAT is the middle of it, and it replaces a RANK beat. The avatar used to claim to be
-- the baron of Bellmere's child, and the guard used to walk straight past the claim into his next
-- routine question -- a piece of business that only worked while the avatar had a name worth not
-- checking. There is no rank now. What the avatar hands over is a company and a job: Ninth Charter,
-- out of Bellmere, two left of it. The guard's answer does the same work the old one did, in one
-- sentence -- he tells them the paper is worthless, because the town it was written against is gone.
--
-- Then the plate lands, and that is unchanged and load-bearing: THE ONLY CREDENTIAL IN THIS PARTY IS
-- ROWAN'S. They get through the gate on the Order's name rather than on anything the avatar has,
-- which is the note Act 1 keeps hitting.
--
-- THE GUARD POINTS AT THE RIFT, and names it -- data/buildings/the_gate.lua's `name` must agree. It
-- used to be the Adventurers' Guild, with a sponsor intercepting the party in the street a scene later
-- to redirect them; that sponsor is cut, and the stair coaches its own button (states/gate.lua).
--
-- He is not advertising a job, he is explaining a standing problem: the Rift has to be cleared deep and
-- often, few can and fewer will, so what gathers on the untouched floors gets out. That is also the
-- answer to the queue he is standing in, which is what ties the refugee beat to the premise.
--
-- WHAT THE RE-PREMISE ADDS TO HIS LAST LINE is "no charter covers it". A field tear in the shires is
-- licensed work for a company of a dozen -- that is the trade the party is already in, and the trade
-- the whole eastern line just proved too small. The thing under this city is not that: it is permanent,
-- it is deeper than any paper was written for, and it is paid by the trip to whoever will go down it.
-- That is the escalation Act 0 exists to set up, and it is one clause.
--
-- The city's ECONOMIC dependence on the Rift is deliberately not here -- no market stocked out of it,
-- no treasury. It is a hole that has to be kept clear, and the reason to go down is that it pays.
--
-- ONE THING HE MUST NOT TAKE FROM ISELLE: he says the deep floors get left, never "pruning". The
-- trade's nickname is hers to introduce.
return {
    title = "The Capital",
    cast  = { { id = "townsfolk", name = "Townsfolk" }, { id = "guard", name = "City Guard" }, "character_rowan", "character_avatar" },

    script = {
        { "character_avatar", "There it is. Walls still standing, gates still shut.", tag = 1 },
        { "character_rowan", "The Bastion holds this wall. If anywhere's still standing, {name}, it's behind these stones.", tag = 2 },
        { "townsfolk", "More of them. Third column through the gate since morning. Where are we meant to put them all?", tag = 3 },
        { "townsfolk", "Not under my roof. Barely bread enough for the mouths already inside.", tag = 4 },
        { "guard", "Off the road, with the others. Names, and where you've run from.", tag = 5 },
        { "character_avatar", "Ninth Charter, out of Bellmere. There's two of us left of it.", tag = 14 },
        { "guard", "Bellmere. That's the whole eastern line gone, then. Your paper burned with the town it was written against.", tag = 15 },
        { "guard", "...That plate. That's Bastion steel. Forgive me, ser. Pass, the pair of you.", tag = 7 },
        { "guard", "It won't stop, either. The Rift under this city has to be cleared, deep and often.", tag = 10 },
        { "guard", "Not many can, and fewer will. So the deep floors get left, and whatever's down there comes up.", tag = 11 },
        { "guard", "That's what this street is running from. No charter covers it -- it pays by the trip. Better than queuing for bread, if you can still hold a blade.", tag = 16 },
        { "character_rowan", "The Rift, then. We'll want coin before we want anything else.", tag = 13 },
    },
}
