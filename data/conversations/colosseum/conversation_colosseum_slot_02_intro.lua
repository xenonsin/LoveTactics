-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 2 intro (data/quests/colosseum/quest_colosseum_slot_02.lua). The promoter warms the crowd with a
-- bout that is not one: the "opponents" are the capital's newest REFUGEES -- unarmed, desperate, off the
-- same road the player fled down -- carded against the house's killers, because the crowd has learned to
-- hate the refugees the war keeps delivering and will pay to watch them die. The village elder the
-- player and Rowan carried out of the fire in the prologue is among them. The player takes the refugees'
-- side. (The overrule -- Ira -- lands in the outro; keep her out of this scene.)
-- Saber's cost this slot: the first crack in "the sport is clean." A veteran of the sand, she has
-- watched promoters run this play for years -- she knows exactly what she is looking at, is plainly
-- disgusted, and is first onto the sand between the killers and the refugees before anyone asks.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model (full roster). Saber is scaffolded below.
return {
    title = "The Padded Card",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } }, { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "colosseum", "BEAT: the promoter frames tonight's opener as a warm-up -- and lets slip what the crowd is really here to see: the road's newest arrivals put down.", tag = 1 },
        { "character_avatar", "BEAT: the avatar reads the far side of the sand -- these people were not brought here to fight; they are refugees, off the same road we came in on.", tag = 2 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "BEAT: Rowan recognizes the village elder among them -- one of the people they carried out of the fire in the prologue -- swept off the bread line and onto the sand.", tag = 3 },
        } },
        { "colosseum", "BEAT: the crowd hates them and paid to watch them bleed; the house only prints what sells, and the card is already set.", tag = 4 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber already knows what this is -- she has watched promoters run it for years -- and does not look away.", tag = 5 },
            { "character_saber", "BEAT: she is going down onto the sand first -- between the killers and the refugees -- before anyone asks her to; everyone gets to walk off it.", tag = 6 },
        } },
        { "character_avatar", "BEAT: the choice lands on the player -- hold the line for these people, or let the house have its slaughter.", tag = 7 },
    },
}
