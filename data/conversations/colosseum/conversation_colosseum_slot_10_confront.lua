-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- the written dialogue has been removed; each line's text is a BEAT (what the line must
-- accomplish), not prose. Write your dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp the ids. The previous written scene is preserved
-- in git: `git show HEAD:data/conversations/colosseum_general_wrath_confront.lua`.
--
-- The opening of data/quests/colosseum/quest_colosseum_slot_10.lua -- the only seam an antagonist speaks
-- from (states/game.lua). The two-phase transform is a FIGHT event (trait_boss_phases on her Unappeased
-- Heart sheds her into character_general_wrath_demon at 40%), NOT part of this opening -- she speaks here
-- as the SULLEN human, phase one: the woman who wanted out.
--
-- CANON (revised 2026-07-28): she CHOSE the pact. Owned by the Perennial all her life, promised freedom
-- and the strength to seize it, she bargained with the Demon Lord herself and got an uncontrollable rage
-- instead -- a deeper cage. Write to these:
--   * She must never ASK to die. She wanted to be FREE, not gone. She rages to keep the one thing left
--     that is hers; killing her is the only door still open, and SABER is the one who names it, not Ira.
--   * Never operatic -- the register is quiet and interior. The horror is a life spent owned.
--   * She is a superb, sharp fighter -- she reads the room by skill and weight, NOT by any deficit.
--   * Saber is SYMPATHY, not recognition -- a free fighter looking at a caged one. Saber was NEVER in
--     the Perennial's program; drop every "washed out / version of herself" beat.
return {
    title = "Ira, the Unappeased",
    cast  = { "character_general_wrath", "character_avatar", { id = "character_saber", when = { has = "character_saber" } }, { id = "character_rowan", when = { has = "character_rowan" } }, { id = "character_amana", when = { has = "character_amana" } }, { id = "character_gyeom", when = { has = "character_gyeom" } }, { id = "character_kaya", when = { has = "character_kaya" } }, { id = "character_ren", when = { has = "character_ren" } }, { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "character_general_wrath", "BEAT: she reads that they arrive already wounded (one favours a foot). They fought their way to her; everything that reaches her is a card.", tag = 1 },
        { "character_general_wrath", "BEAT: the bout was set for the ninth; they moved it up and no one told her. She is told when she fights, never asked.", tag = 2 },
        { "character_avatar", "BEAT: the avatar catches on 'told, never asked'.", tag = 3 },
        { "character_general_wrath", "BEAT: every fight of her life was set for her by someone else; the sand was the only place she ever moved on her own accord, and that is exactly why she is good at it.", tag = 4 },
        { when = { has = "character_saber" }, script = {
            { "character_general_wrath", "BEAT: she reads Saber. No house-weight on her, moves like she could walk off any moment.", tag = 5 },
            { "character_saber", "BEAT: Saber names her.", tag = 6 },
            { "character_general_wrath", "BEAT: Saber fights because she wants to; Ira was never once allowed to want to.", tag = 7 },
            { "character_saber", "BEAT: Saber. 'I fight because I love it. You fight because it's the only door they ever left open.'", tag = 8 },
            { "character_general_wrath", "BEAT: the only door, yes, and she went and found herself a second one, and it closed behind her.", tag = 9 },
        } },
        { "character_general_wrath", "BEAT: she will tell them what she is, because they will not otherwise believe it of a person.", tag = 11 },
        { "character_general_wrath", "BEAT: made by the Perennial to win. Owned since before she can remember, drilled before she could choose anything at all.", tag = 12 },
        { "character_general_wrath", "BEAT: she was superb, and none of it was hers. Never once chose a fight, an opponent, a morning.", tag = 13 },
        { "character_general_wrath", "BEAT: the one thing she ever wanted was to belong to herself; she held it down for years, sullen and hidden, and it was the engine of everything the crowd cheered.", tag = 14 },
        { "character_general_wrath", "BEAT: so she made the bargain herself. The Demon Lord promised freedom, and the strength to take it.", tag = 15 },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "BEAT: Ren. 'and it gave you?'", tag = 16 },
            { "character_general_wrath", "BEAT: strength, and a rage she cannot govern, not a way out but a deeper cage, one she now carries inside.", tag = 17 },
            { "character_ren", "BEAT: Ren knows the shape of that bargain, and can barely say it.", tag = 18 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "BEAT: Clem, so there is no getting out now, no term to serve, no price that buys it back.", tag = 19 },
            { "character_general_wrath", "BEAT: no; she spent her freedom on the lock.", tag = 20 },
        } },
        { when = { has = "character_amana" }, script = {
            { "character_amana", "BEAT: Amana. How old were you when they took you.", tag = 21 },
            { "character_general_wrath", "BEAT: there was no before; no part of her predates the house.", tag = 22 },
            { "character_amana", "BEAT: Amana knows a house that takes children; did not know there were two.", tag = 23 },
        } },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "BEAT: Rowan, and the stable never once said what it had made.", tag = 24 },
            { "character_general_wrath", "BEAT: it cannot; saying what she is means saying its champions are owned, and the intake is still running. Children in it tonight.", tag = 25 },
        } },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "BEAT: Gyeom. A fighter who is not allowed to stop is not a champion, it is a chained dog.", tag = 26 },
            { "character_general_wrath", "BEAT: yes; she has been told she is the finest chained dog in the world.", tag = 27 },
        } },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "BEAT: Kaya. Everything in a wood can run, and the running is what keeps it alive; they built her with the leaving taken out.", tag = 28 },
            { "character_general_wrath", "BEAT: they took out the leaving, not the wanting. That was their mistake.", tag = 29 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_general_wrath", "BEAT: she has heard Saber once put her sword down on a full house and would not finish a slaughter.", tag = 30 },
            { "character_saber", "BEAT: Saber. They died anyway; someone else did it while she stood there.", tag = 31 },
            { "character_general_wrath", "BEAT: she thinks of that. A fighter who was allowed to choose to stop, on a sand where Ira never was.", tag = 32 },
            { "character_saber", "BEAT: Saber. She came believing she could get Ira OUT; that there was somewhere else to put her, some other door.", tag = 34 },
            { "character_general_wrath", "BEAT: there is no other door; she bought the last one, and this is what was on the far side of it.", tag = 35 },
            { "character_general_wrath", "BEAT: 'I bought my way out. This is what was on the other side.'. The line the whole scene turns on.", tag = 36 },
        } },
        { "character_general_wrath", "BEAT: come and hit her PROPERLY, not fast; a fast blow is a blow held back, and she is done holding anything back.", tag = 37 },
        { "character_general_wrath", "BEAT: every blow wakes more of it; the nearer she is to gone, the less of her is left to hold it, and she will not hold it.", tag = 38 },
        { "character_avatar", "BEAT: the avatar. That is not a reason to keep going.", tag = 39 },
        { "character_general_wrath", "BEAT: it is the only thing left that is hers to spend, and she means to spend all of it; begin.", tag = 40 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber. 'Everyone gets to walk off the sand.' Ira never could.", tag = 41 },
            { "character_saber", "BEAT: ...so she is going to carry her off it the only way that is left, and would rather no one call it mercy. Even though it is.", tag = 42 },
        } },
    },
}
