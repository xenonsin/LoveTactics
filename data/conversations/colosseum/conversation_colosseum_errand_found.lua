-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- SABER, MET AT THE COLOSSEUM'S POSTING, and hers is the odd one of the six: every other companion asks
-- you to go and fight something else, and the thing behind Saber's door is Saber. The debut bout IS her
-- ask (data/quests/colosseum/quest_colosseum_slot_01.lua -- character_saber_bout and a netter), so this
-- scene is a body at a doorway offering herself as the work, which is exactly what the arena's
-- gatekeeper does: she fights every newcomer, waiting for the pair who can beat her
-- (data/characters/character_saber.lua).
--
-- HER VOICE IS THE ONE ALREADY ON THE SAND -- clipped, contracted, generous with what she knows -- and
-- conversation_colosseum_slot_01_confront.lua is the reference; she gives away her own tell there,
-- inside the bout, for free. Nothing here may spend that: the swing is the confront scene's to name.
--
-- She is the only one of the six who does not need the company. That is the point of her patience: she
-- has enough, every fight, and can walk off any time -- so the ask is an invitation rather than a plea.
return {
    title = "The Card's Opener",
    cast  = { "character_avatar", "character_saber", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_saber", "There you are. No house, no record, and you came all the way down here anyway. That's already the most interesting thing on the card.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { "character_saber", "Through that door it's me, and a netter the house booked to make it honest, and a crowd that doesn't know your name yet. That's the whole bout. I'm not going to dress it up for you.", tag = 3 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She is telling you the composition of the room she means to beat you in, {name}. Nobody does that who is worried.", tag = 4 },
        } },
        { "character_saber", "I open the same way every time. Years of it. Nobody's read it yet and I've stopped waiting for somebody to, which is the only reason I still enjoy the job.", tag = 5 },
        { "character_saber", "Beat me and I'm yours. I go where I like -- and I'd like to go with whoever finally reads the swing.", tag = 6 },
        { "character_avatar", "We take the bout, or we leave her standing. Choose...", tag = 7, choices = {
            { "Take the bout.", tag = 8, answer = "accept" },
            { "Leave her standing.", tag = 9, answer = "decline" },
        } },
    },
}
