-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The arrival at the capital, played OVER the hub city on the first visit (states/hub.lua reads the
-- prologue's hubIntro flag). Its job is to turn a sudden hub into an arrival: the survivors are
-- processed at the gate, Rowan's plate is recognized, and the guard points them at the Rift.
--
-- THE RANK BEAT is the middle of it. The avatar says who they are and it does not land -- the guard
-- acknowledges the TOWN and walks straight past the claim into his next routine question. A baron's
-- second child is not a thing anyone disbelieves, it is a thing nobody bothers to check, and there is
-- nothing left to check it with: a small holding's seal and papers lived in its keep, and the keep
-- burned in a night with everyone in it. Then the plate lands. The only credential in this party is
-- Rowan's, and they get through the gate on the Order's name rather than the avatar's.
--
-- THE GUARD POINTS AT THE RIFT, and names it -- data/buildings/the_gate.lua's `name` must agree. It
-- used to be the Adventurers' Guild, with a sponsor intercepting the party in the street a scene later
-- to redirect them; that sponsor is cut, and the stair coaches its own button (states/gate.lua).
--
-- He is not advertising a job, he is explaining a standing problem: the Rift has to be cleared deep and
-- often, few can and fewer will, so what gathers on the untouched floors gets out. That is also the
-- answer to the queue he is standing in, which is what ties the refugee beat to the premise.
--
-- The city's ECONOMIC dependence on the Rift is deliberately not here -- no market stocked out of it,
-- no treasury. It is a hole that has to be kept clear, and the reason to go down is that it pays.
--
-- TWO THINGS HE MUST NOT TAKE FROM ISELLE. He never says Bellmere -- he gives the rule, she applies it
-- to this party's dead town. And he says "kept down", not "pruning": the trade's nickname is hers to
-- introduce.
return {
    title = "The Capital",
    cast  = { { id = "townsfolk", name = "Townsfolk" }, { id = "guard", name = "City Guard" }, "character_rowan", "character_avatar" },

    script = {
        { "character_avatar", "There it is. Walls still standing, gates still shut.", tag = 1 },
        { "character_rowan", "The Bastion holds this wall. If anywhere's still standing, {name}, it's behind these stones.", tag = 2 },
        { "townsfolk", "More of them. Third column through the gate since morning. Where are we meant to put them all?", tag = 3 },
        { "townsfolk", "Not under my roof. Barely bread enough for the mouths already inside.", tag = 4 },
        { "guard", "Off the road, with the others. Names, and where you've run from.", tag = 5 },
        { "character_avatar", "I'm the baron of Bellmere's child. The town burned four nights ago.", tag = 14 },
        { "guard", "Bellmere. That's the whole eastern line gone, then. Papers, a seal, anything to say who you are?", tag = 15 },
        { "guard", "...That plate. That's Bastion steel. Forgive me, ser. Pass, and the ones at your back.", tag = 7 },
        { "guard", "It won't stop, either. The Rift under this city has to be cleared, deep and often.", tag = 10 },
        { "guard", "Not many can, and fewer will. So the deep floors get left, and whatever's down there comes up.", tag = 11 },
        { "guard", "That's what this street is running from. It's also work, if you can hold a blade. Better than queuing for bread.", tag = 16 },
        { "character_rowan", "The Rift, then. We'll want coin before we want anything else.", tag = 13 },
    },
}
