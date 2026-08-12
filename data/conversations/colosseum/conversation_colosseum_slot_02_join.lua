-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The `epilogue` of data/quests/colosseum/quest_colosseum_slot_02.lua, played straight after the outro
-- (states/game.lua's epilogue seam). The outro ended with the whole company dead on the sand. This
-- scene opens on a ceiling in the Cathedral, and it is where AMANA is recruited: her join, moved off
-- the Cathedral's second slot, where the church used to brand her fallen and hire the player to purge
-- her (docs/story.md, "The Cathedral"). Player.recruit has already run by the time this plays and the
-- banner was held across the outro for it (`deferJoins`), so the join lands here.
--
-- WHO PAID. The stables. They watched the debut and they watched the padded card, and what the house
-- destroyed on that sand was a draw they had money on, so they bought it back. The Cathedral sells the
-- rite; the sponsors met the price; the party is a receipt. Nobody in this scene pretends otherwise,
-- and the promoter's house is not forgiven by it.
--
-- WHY SHE LEAVES WITH THEM, and this is the payload of the scene: the refugees came in on the same
-- cart and nobody paid for them. Amana is the acolyte who enters the Cathedral's dead in the intake
-- register, and what she wrote beside eleven names off that sand is ASCENDED TO THE LIGHT. She carried
-- them to the pit behind the almshouse herself. The party is the only living witness to what actually
-- happened out there, so she goes where the truth can still be carried. That is her rule read forward:
-- she gives what is offered and refuses what is not, and she will not let the book be the last word on
-- people she watched come in.
--
-- WHAT SHE DOES NOT SAY, and the constraint that shapes every line here: the blooding. She knows the
-- rite puts demon's blood into children and she knows the ferals the church hunts are its own failures,
-- and she says NONE of it. She names the book and stops at the book. That reveal belongs to the
-- Cathedral's line, where the player has to walk the distance between the register and the pit for
-- themselves (data/quests/cathedral/quest_cathedral_slot_04.lua and slot 5). One line here marks the
-- withholding plainly so it is a promise rather than a trick.
--
-- ALSO DELIBERATELY UNSAID: where the power to raise four dead fighters comes from. The Cathedral's
-- "holy" magic is Luxuria's blood (docs/story.md, "The blooding"), which would make this rite the
-- demon's own work and the party her creditors. That is a canon decision the line has not taken, so
-- the scene calls it the rite, says what it costs, and leaves the door open.
--
-- Only Rowan and Saber can be on the roster this early, so they are the only companion blocks
-- (companions-speak-in-every-scene). Amana's second cost stays in the subtext, as it always does:
-- taken as a child and renamed for a virtue, taught to want nothing for herself, so she offers rather
-- than asks. The avatar's answer to that is the one thing this scene keeps from the old plea.
return {
    title = "Ascended to the Light",
    cast  = { "character_amana", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } }, { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "character_avatar", "This is not the arena. Where am I?", tag = 1 },
        { "character_amana", "Lie still a moment. You have been dead since the third bell.", tag = 2 },
        { "character_avatar", "Dead.", tag = 3 },
        { "character_amana", "All of you. They brought you in on the cart with the rest. I have had my hands on your heart for an hour.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "I remember the sand. I remember standing in front of you and then nothing at all.", tag = 5 },
        } },
        { "character_amana", "This is the Cathedral. I am Amana. I am an acolyte here, and the rite that brought you back is the most expensive thing this house owns.", tag = 6 },
        { "character_avatar", "We have no money for that.", tag = 7 },
        { "character_amana", "You did not pay for it. Four stables did, before your bodies were cold.", tag = 8 },
        { "character_amana", "They watched you fight twice and they had coin on you, and the house they book with destroyed you in front of them. So they bought you back to fight again.", tag = 9 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Of course they did. A dead draw earns nobody anything.", tag = 10 },
            { "character_saber", "Hear it plainly, {name}. We are owned by four men we have never met until we win it back.", tag = 11 },
        } },
        { "character_avatar", "What about the people on the sand with us?", tag = 12 },
        { "character_amana", "...They came in on the same cart. Eleven of them.", tag = 13 },
        { "character_amana", "No one paid for them.", tag = 14 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "There was an elder among them. Grey, small, a burn across one hand. Tell me where they are.", tag = 15 },
            { "character_amana", "I can tell you exactly where. I carried them there myself.", tag = 16 },
        } },
        { "character_amana", "There is a book in this house. Every soul the Cathedral receives goes into it, and I am one of the hands that writes it.", tag = 17 },
        { "character_amana", "I wrote all eleven of them in this morning. Ascended to the Light. That is the wording. It is the only wording there is.", tag = 18 },
        { "character_amana", "Then I took them out the back to the pit behind the almshouse, and there is no marker on it, and there never has been.", tag = 19 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Ascended. They were butchered on a sand floor for a crowd.", tag = 20 },
            { "character_amana", "I know what they were. I am the only one in this building who does.", tag = 21 },
        } },
        { "character_amana", "That book has other names in it. Older ones. I will not talk about those tonight and I am asking you not to make me.", tag = 22 },
        { "character_avatar", "Then talk about the eleven.", tag = 23 },
        { "character_amana", "There is nobody left to. Everyone who stood on that sand and saw it is in the pit, and you are lying in front of me.", tag = 24 },
        { "character_amana", "You are the last people alive who know what actually happened out there. By the feast day this house will have read those names aloud as saints and meant it.", tag = 25 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "My order carves a mark for every one of its dead and teaches children the marks are days held. Same trick. Different stone.", tag = 26 },
        } },
        { "character_amana", "So I am not staying here. Take me with you.", tag = 27 },
        { "character_avatar", "You just gave us our lives back. Why ask?", tag = 28 },
        { "character_amana", "Because a thing given is not a thing owed. You are free of me the moment you stand up.", tag = 29 },
        { "character_amana", "I want to be standing somewhere the truth can still be carried, and there is one outfit in this city that is not the house or the faith or the stables. It is you.", tag = 30 },
        { "character_amana", "I will not ask you for a wage, or a share, or a say in where we go. I have never been much good at wanting things for myself. They were thorough about that.", tag = 31 },
        { "character_avatar", "You can want a wage too. We will start there.", tag = 32 },
        { "character_amana", "...I will think about it.", tag = 33 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Then get your boots, priest. And keep close to me on the road.", tag = 34 },
        } },
    },
}
