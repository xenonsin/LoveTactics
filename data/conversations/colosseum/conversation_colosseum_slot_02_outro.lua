-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Slot 2 outro (data/quests/colosseum/quest_colosseum_slot_02.lua). The turn of the slot. The player
-- WON: the carded killers are down and the refugees, the village elder among them, are still standing.
-- Because they held, the crowd was denied its death the cheap way, so the house sends the one
-- instrument that never fails: IRA walks onto the sand and kills the refugees anyway.
--
-- AND THEN SHE KILLS THE PARTY. That is the whole scene. The first thing the player ever sees Ira do
-- is take the walk-off away, and the second thing is take it away from THEM. It is not a fail-state
-- and it is not a fight: the objective is already won when this plays, so what the player loses here
-- is not the quest, it is the company's lives after winning.
--
-- SHE DOES NOT SPEAK, and she is not in the cast; slot 7 is her first word.
--
-- THE HOUSE MEANT ALL OF IT. The promoter is not surprised and is not panicking. He sold a night of
-- blood and the crowd is owed one, and when the player's win threatened to send them home short the
-- house put its patron on the sand to finish the card. The refugees were the promise; the party is the
-- rest of the promise. His lines at the end are the coldest in the scene and must stay that way: the
-- house is not losing control of Ira here, it is USING her, and slot 7 is where the player finds out
-- what using her costs. Do not let him beg for her to be taken off. He wants the sand cleared.
--
-- WHY THERE IS ANYTHING AFTER THIS. The venue and the stables are not the same people (docs/story.md,
-- "The league and the stables"). The house spent a new draw for one night's crowd; four stables with
-- money on that draw did not agree, and they buy it back before the bodies are cold. The epilogue is
-- that receipt.
--
-- The scene ends on the avatar going down. The next thing the player sees is the epilogue
-- (data/conversations/colosseum/conversation_colosseum_slot_02_join.lua), which opens on a ceiling.
-- Amana is already on the roster by now (this slot's rewardCharacter) and her join banner is held
-- across this scene by `deferJoins`, because a recruit has no business in a scene where everyone dies.
--
-- What it costs Saber: everyone walks off the sand is her one law, and it breaks twice in front of her
-- here, the second time under her own feet. It is the exact shape of the thing that broke her once
-- already (slot 10: "they died anyway; someone else did it while she stood there"), and this is the
-- seed that slot pays off.
return {
    title = "The Padded Card",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } }, { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_avatar", "The killers are down. Every refugee is still standing.", tag = 1 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "The elder is up, {name}. We have carried that one out of two fires now.", tag = 2 },
        } },
        { "colosseum", "Well fought. The house has no complaint with you.", tag = 3 },
        { "colosseum", "The crowd paid for a night, though. The house always gives them the night. Watch the far gate.", tag = 4 },
        { "character_avatar", "Someone is coming out onto the sand.", tag = 5 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "That is the patron. Get behind me and do not raise your sword to her.", tag = 6 },
        } },
        { "colosseum", "Her own hand, and on an opener. You will not see that twice in a life.", tag = 7 },
        { "character_avatar", "She is walking at the refugees.", tag = 8 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Get in front of them! All of you, in front of them!", tag = 9 },
        } },
        { "character_avatar", "They are down. All of them are down.", tag = 10 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "The elder is dead. Dead on the floor of a sport.", tag = 11 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Everyone walks off the sand. That is the one law this place ever kept.", tag = 12 },
        } },
        { "character_avatar", "She has not stopped. She is coming to us.", tag = 13 },
        { "colosseum", "The crowd wanted blood tonight. The house does not send them home short.", tag = 14 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "They sent her for this. She was always taking the whole card.", tag = 15 },
        } },
        { "character_avatar", "Then we put her down. Weapons up.", tag = 16 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Do not. Run for the gate, {name}. Run!", tag = 17 },
        } },
        { "colosseum", "The card is filled. That is all the house ever promised anyone.", tag = 18 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Behind me, {name}. Behind me!", tag = 19 },
        } },
        { "character_avatar", "I am on my back. I cannot get up.", tag = 20 },
        { "character_avatar", "The crowd is standing. They are cheering.", tag = 21 },
    },
}
