-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 2 outro (data/quests/colosseum/quest_colosseum_slot_02.lua). The turn of the slot. The player
-- WON: the carded killers are down and the refugees -- the village elder among them -- are still
-- standing. Because they held, the crowd was denied its death the cheap way, so the house sends the one
-- instrument that never fails: IRA walks onto the sand and kills the refugees anyway. She does not
-- speak (slot 7 is her first word); her arrival and the killing are narrated by the others -- keep her
-- OUT of the cast so no line is attributed to her here. The first thing the player ever sees Ira do is
-- take the walk-off away, and it is the exact shape of the thing that broke Saber (slot-10 confront:
-- "they died anyway; someone else did it while she stood there").
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber and Rowan are scaffolded below.
return {
    title = "The Padded Card",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } }, { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_avatar", "BEAT: it is done -- the house's killers are down and the refugees, the elder among them, are still on their feet; the player held the line.", tag = 1 },
        { "colosseum", "BEAT: the promoter is unbothered -- the crowd was promised a night, and the house always keeps its promises; watch.", tag = 2 },
        { "character_avatar", "BEAT: the patron is sent down onto the sand; the avatar reads what is about to happen and cannot reach it in time.", tag = 3 },
        { "character_avatar", "BEAT: Ira cuts the refugees down without a word -- wordless, unhurried, obedient -- the house's final answer to a card that would not fill itself. The player's win is overruled.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "BEAT: Rowan -- the elder they carried out of the fire, dead on the sand anyway; her oath was to bring people out, and this house exists to put them back in.", tag = 5 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber, quiet -- everyone gets to walk off the sand; that is her one law, and she just watched it broken in front of her.", tag = 6 },
            { "character_saber", "BEAT: she has seen this exact thing before -- she put her sword down once and someone else finished it while she stood there; she does not say so yet, but the recognition is on her face.", tag = 7 },
        } },
        { "character_avatar", "BEAT: the avatar marks who did it -- not a nameless enforcer, the patron herself -- and the line's real question opens: what is she.", tag = 8 },
    },
}
