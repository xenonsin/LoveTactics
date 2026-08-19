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
-- THE STAIR IS NOT A SECRET AND THIS SCENE IS NOT A REVELATION. Earlier drafts had Iselle disclosing a
-- hole nobody sensible would go into. That was backwards for the game the descent turned into: the
-- capital sits on the Rift, the Rift is where the city's money comes from, and four houses pay companies
-- to dig it. Iselle's house is one of the four and it is the smallest, which is the whole reason she is
-- hiring off the road instead of off the board. The information the scene carries is not "there is a
-- hole", it is the TRADE: who pays, who competes, and what the Crown buys.
--
-- WHAT PRUNING IS, because it is the campaign's premise in one word. Things breed down there. The Crown
-- pays by the floor to keep the count down, and when nobody goes deep enough they come up the stair and
-- out into the country. That is what happened to Bellmere. The prologue's own scenes call it the Demon
-- Lord's army and never say where it came from; Iselle is where the player finds out, and it turns the
-- descent from a job into the answer to the first fight in the game.
--
-- WHAT SHE ACTUALLY OFFERS, because the terms are the mode: she stakes the expedition -- the hirelings,
-- the kit, the room at the inn -- and the company keeps what it brings up and sells it at her counter.
-- That is the loop stated as a deal, and it is why the gate has a store and a hiring hall and no quest
-- giver.
--
-- She is not a villain and this is not a trap. She is a small house in a crowded trade, staking a fifth
-- company because four went down this season and two came back. The register is plain and transactional:
-- she is offering a job, and everyone in the scene knows it is the only one going.
--
-- Rowan speaks without a `when` block: at this point in the prologue she is sworn and standing there by
-- construction, so a conditional would be guarding against a party that cannot exist.
return {
    title = "The Rift",
    cast  = { { id = "sponsor", name = "Iselle" }, "character_rowan", "character_avatar" },

    script = {
        { "sponsor", "Before you join that queue. You are the two who came in with the Bellmere column, and one of you is wearing Bastion plate.", tag = 1 },
        { "character_avatar", "We were told to register at the guild.", tag = 2 },
        { "sponsor", "You were. Eleven hundred people in this city can hold a blade and every one of them is standing in that line.", tag = 3 },
        { "sponsor", "They are all queuing for the same work. I am offering it to you here, and I pay better than the board does.", tag = 4 },
        { "character_rowan", "Say it plainly.", tag = 5 },
        { "sponsor", "The stair under the north quarter. You will have seen the lamps over it on your way in. Everyone calls it the Rift.", tag = 6 },
        { "sponsor", "The city sits on it. The market you walked through is stocked out of it, and so is the treasury.", tag = 7 },
        { "sponsor", "Four houses pay companies to go down and dig. Mine is one of the four. Mine is the smallest.", tag = 8 },
        { "character_avatar", "And the things that live down there?", tag = 9 },
        { "sponsor", "They breed. That is the other half of the trade. The Crown pays by the floor to keep the count down, and we call it pruning.", tag = 10 },
        { "character_rowan", "The Crown should have soldiers down there.", tag = 11 },
        { "sponsor", "It has. Two companies of the Watch, on the first three floors, and they will not go past them.", tag = 12 },
        { "sponsor", "So the deep floors go unpruned. Then the count climbs, and what is down there comes up the stair and out into the country.", tag = 13 },
        { "character_rowan", "The eastern line.", tag = 14 },
        { "sponsor", "Bellmere, four nights ago. That did not come over the hills, it came up out of this ground.", tag = 15 },
        { "sponsor", "Here are my terms. I pay for the people you pull out, the steel they carry and the bed they sleep in.", tag = 16 },
        { "sponsor", "Whatever you bring up is yours. You sell it at my counter and I take my share there.", tag = 17 },
        { "character_avatar", "That is a great deal of coin to stake on strangers.", tag = 18 },
        { "sponsor", "I staked four companies this season and two of them came back up. I need people who will go deeper than that.", tag = 19 },
        { "character_rowan", "{name}. The wall we held is ash and there is nothing east of here to go back to. This is work, and it is the only work.", tag = 20 },
        { "character_avatar", "Then we go down.", tag = 21 },
        { "sponsor", "The stair is the far side of the north quarter. Beside it there is a smaller tear that people come up out of. Take whoever it gives you, and be sensible about how deep you go on the first day.", tag = 22 },
    },
}
