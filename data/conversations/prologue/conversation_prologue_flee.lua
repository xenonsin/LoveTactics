-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Standing in the ash of Bellmere, and the scene the whole Rowan line is built on. IT USED TO BE AN
-- OATH SCENE and it is not one any more. Rowan arrived at this holding carrying an ASSIGNMENT -- the
-- Order posted her to the baron and the baron's child was the duty -- and the scene took the
-- assignment away and let her swear a vow of her own in the gap. Both halves of that are gone with
-- the re-premise: there is no baron, no posting, and nothing is sworn to anybody here.
--
-- WHAT REPLACES IT IS A CHOICE INSTEAD OF A VOW. The two of them are hands of the Ninth Charter, a
-- chartered rift company, and Bellmere was a paid job the paper under-read. The rest of the Ninth
-- went down the lane at dusk and did not come back up it. So the scene still strips Rowan of every
-- institution standing behind her -- the charter is void and the company is dead -- and "we go on" is
-- still the first thing she says with nobody above her to say it for her. What changed is that she
-- ASKS. The old line's whole flaw was that she decided you were a "we" without consulting you; this
-- one puts the question in the sentence and lets the avatar answer it, which is the difference
-- between a friend and a bodyguard.
--
-- THE BASTION IS OFFERED AND REFUSED, which is where she gets explained. The player learns in two
-- lines that she is Order-trained, that the plate is real, that she could walk back into it tonight,
-- and that she would rather work a charter. It replaces "my orders were one line" and does the same
-- job -- the first statement in the game of what she is and why she is here -- without an order in it.
--
-- "I'VE BEEN LATE BEFORE" IS A SEED AND MUST STAY ONE. It is one clause, it names nothing, and it is
-- the earliest the Greywatch wound is ever touched. Do not let a later pass expand it: the reveal is
-- the Bastion line's to spend, and the rank-4 shield is meant to reach the player before Rowan does
-- (docs/story.md, "Rowan, the same wound answered the other way").
--
-- THE FATHER IS NOT HERE AND NEITHER IS A HOUSEHOLD. Nobody the avatar is related to is in this
-- prologue at all; the loss the scene carries is the company's, which is a thing both of them lost
-- and can therefore be talked about between equals. The sibling Bryn went earlier, with
-- conversation_prologue_intro (see conversation_prologue_village.lua for that deletion).
--
-- WHAT THE MECHANICS STILL WANT, unchanged: data/traits/trait_oathward.lua guards whatever ally is
-- standing next to her, undiscriminating, and it is now a compulsion with NO vow underneath it --
-- which is a sharper reading of the same trait, not a weaker one. Oath three
-- (data/items/utility/utility_struck_name.lua) still names ONE ally, and it now has further to climb:
-- she starts the game promising nothing to anyone.
--
-- "[Rowan has joined your Party]" lands at the end of this scene (Conversation.drainJoins; see the
-- comment in states/prologue.lua for why it survives the fight in between). She was already beside
-- you for the fight, so what the banner marks is not a stranger arriving -- it is the Ninth ending and
-- the company that is yours starting at two.
return {
    title = "Ashes",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_avatar", "Half the town made the west road. I keep counting the half that didn't.", tag = 11 },
        { "character_rowan", "You count them later, {name}. Everyone counts them later.", tag = 12 },
        { "character_avatar", "The Ninth went down that lane at dusk. We came up an hour behind them.", tag = 13 },
        { "character_rowan", "I know what hour we came up. I've been late before. Don't hand me this one as well.", tag = 14 },
        { "character_avatar", "There's no company left to report to, and no charter to report on.", tag = 15 },
        { "character_rowan", "The charter was signed in the capital. Another one gets signed there.", tag = 16 },
        { "character_avatar", "You don't need another one. The Bastion would take you back tomorrow, plate and all.", tag = 17 },
        { "character_rowan", "They would. Fifteen years somebody has told me where to stand, and tonight there's nobody left to tell me.", tag = 18 },
        { "character_rowan", "So we go on. If you'll have me on the road.", tag = 19 },
        { "character_avatar", "Go on where? The field is still open.", tag = 9 },
        { "character_rowan", "Away from it. The capital, {name}. Tonight.", tag = 10 },
        { "character_avatar", "Then don't fall behind.", tag = 20 },
    },
}
