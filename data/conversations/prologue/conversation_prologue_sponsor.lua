-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE SPONSOR, played over the city the moment the guard's arrival scene closes (states/hub.lua reads
-- the prologue's hubIntro flag). It is the hinge of the whole game: the guard has just pointed the party
-- at the Adventurers' Guild, and somebody gets to them first.
--
-- WHY IT IS AN INTERCEPTION and not a notice on the board. The arrival scene ends with the party
-- deciding to register, and the honest way to change what game this is was to have that decision be
-- overtaken rather than rewritten. The board is still there in the fiction. They simply never reach it,
-- because the work with money behind it is standing in the road.
--
-- WHAT SHE ACTUALLY OFFERS, because the terms are the mode: she stakes the expedition -- the hirelings,
-- the kit, the room at the inn -- and the company keeps what it brings up. That is the loop stated as a
-- deal, and it is why the gate has a store and a hiring hall and no quest giver.
--
-- She is not a villain and this is not a trap. The city is full, the work is gone, and there is a hole
-- under it that nobody sensible will go into. She is the person who noticed. The register is plain and
-- transactional: she is offering a job, and everyone in the scene knows it is the only one going.
--
-- Rowan speaks without a `when` block: at this point in the prologue she is sworn and standing there by
-- construction, so a conditional would be guarding against a party that cannot exist.
return {
    title = "The Gate",
    cast  = { { id = "sponsor", name = "Iselle" }, "character_rowan", "character_avatar" },

    script = {
        { "sponsor", "Before you join that queue. You are the two who came in with the Bellmere column, and one of you is wearing Bastion plate.", tag = 1 },
        { "character_avatar", "We were told to register at the guild.", tag = 2 },
        { "sponsor", "You were. The board has four contracts on it and eleven hundred people in the city who can hold a blade. You would be waiting a month.", tag = 3 },
        { "sponsor", "I have work that nobody is queuing for.", tag = 4 },
        { "character_rowan", "Say it plainly.", tag = 5 },
        { "sponsor", "There is a stair under the north quarter. It was a cellar, and then it was deeper than a cellar, and it has been getting deeper since the burning started.", tag = 6 },
        { "sponsor", "Things come up out of it at night. The Watch seals the door and the door does not stay sealed.", tag = 7 },
        { "character_rowan", "And nobody has gone down.", tag = 8 },
        { "sponsor", "Four companies have gone down. None of them has come back up, which is why the fifth is expensive.", tag = 9 },
        { "sponsor", "Here are my terms. I pay for the people you take, the steel they carry and the bed they sleep in. Whatever you bring up is yours.", tag = 10 },
        { "character_avatar", "That is a great deal of coin for somebody else's expedition.", tag = 11 },
        { "sponsor", "It stops coming up the stair. That is what I am buying.", tag = 12 },
        { "character_rowan", "{name}. The wall we held is ash and there is nothing east of here to go back to. This is work, and it is the only work.", tag = 13 },
        { "character_avatar", "Then we go down.", tag = 14 },
        { "sponsor", "The gate is the far side of the north quarter. Hire whoever will take the coin, and be sensible about how deep you go on the first day.", tag = 15 },
    },
}
