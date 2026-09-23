-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE BUBBLES ABOVE GROUND: the one instruction the city itself gives, the ones the Gate and the Ward
-- give, and the three nobody gives any more. A hint bag like the flight leg's -- fetched by id
-- (Locale.coach), never played in order, never spoken by anybody. The windows' longer words are next
-- door in conversation_tutorial_notes.lua.
--
-- EVERY LINE OPENS WITH {select}, because every one of them is asking for a press. The token is what
-- keeps that device-honest: a key cap for pad and keyboard, "Click" for a mouse, "Tap" for a finger
-- (models/locale.lua's coachLine). A line here that wrote "Click" itself would be lying to two of the
-- three inputs this project supports, and tests/tutorial_spec.lua fails the build over it.
--
-- THE PLAZA SPEAKS ONCE, AND ONLY HERE (2026-09-23). Four of the seven lines below were the city's
-- own, and all four went in the cut that took the plaza's coach -- a bubble on a card with every other
-- card refused until that one had been walked into, on the one screen whose job is to be a place you
-- choose in. The REFUSAL was the wrong half and it stays cut. `ward_card` is back without it: a bubble
-- on the Cathedral's plate on the first morning, no door turned down, because the cut left the one
-- lesson that had nowhere else to live with nowhere at all (states/hub.lua's header argues it).
--
-- Everything else fielded is INSIDE a screen, pointing at the control that answers the thing being
-- taught: the Gate's descend row, and the Ward's two rows behind the plate this one names.
--
-- The three still fielded by nobody are kept rather than cut, on the reasoning that kept rift_card
-- twice before -- and that ward_card has now cashed in: a stamped, translated line is dear to lose, a
-- bag is not a cost (Locale.coach fetches by id, so a line nobody asks for is never read), and the day
-- one of them is owed again it costs a draw call rather than a translation pass.
--
-- WHO FIELDS THEM:
--   gate_stair  states/gate.lua  -- the descend row, until the company has actually gone down
--   mend_row    ui/panels/ward.lua -- see below
--   mend_rest   ui/panels/ward.lua -- see below
--   ward_card   states/hub.lua   -- the first morning's ONE coached door, retired with the plaza's
--                                 coach (2026-09-21) and BACK WITHOUT THE RAIL (2026-09-23). The
--                                 company walks out of Act 0 with Rowan hurt, so the city's opening
--                                 instruction is where that gets seen to.
--
--                                 IT WAS RETIRED ON THE ARGUMENT THAT THE LESSON SURVIVED INSIDE THE
--                                 ROOM -- the window in the doorway and the row bubble, both of which
--                                 are still there and still the better half of the teaching. What that
--                                 missed is that both of them are behind a door the player has to
--                                 choose to open first, and nothing told them it was the one. Every
--                                 other plaza line had a second home: the stair is named in Rowan's own
--                                 words one beat earlier, and a grown room says what it is for once you
--                                 are in it. This one had none, and the morning it is about is the one
--                                 where the company is three bodies deep with one of them hurt and the
--                                 next thing the city asks for is four.
--
--                                 IT NAMES ROWAN OUTRIGHT, with no {who} token, and that is right for
--                                 exactly this line: it is drawn on one morning of one save, and the
--                                 body carried out of the Champion's last stage is always hers
--                                 (models/combat.lua's Combat.spendScriptedFell). A token here would be
--                                 a promise that this bubble can point at anybody, which it cannot --
--                                 the room's own rows are the ones that take a name (mend_row).
--   rift_card   nobody           -- RETIRED TWICE OVER. It was the first morning's second door, and
--                                 what retired it the first time was not a deleted card: the arrival
--                                 scene (conversation_prologue_arrival) has Rowan name the Rift and
--                                 point at it one beat earlier, in her own words, so the bubble was
--                                 the same instruction said twice by a hint bag to somebody who had
--                                 just been told.
--   board_card  DELETED          -- it went with the Bounty Board itself, which is deleted rather than
--                                 parked now: its card, its model, its blueprints, its panel and its
--                                 augments. The rift posts the deep work it posted (models/errand.lua).
--   new_door    nobody           -- RETIRED (2026-09-21) with the plaza's coach. It announced every
--                                 room the city grew afterwards, one per morning, wearing the
--                                 blueprint's own sentence as its {door} token. A card that quietly
--                                 stops being locked IS a feature delivered by not being mentioned --
--                                 which is the argument this line was written for, and it lost to the
--                                 plainer one: a plaza that points at a plate and refuses the other
--                                 eight is a corridor with nine doors painted on it.
--
-- AND THE TWO THAT STILL SPEAK INSIDE THE WARD:
--   mend_row    ui/panels/ward.lua -- the Inn's ONE row, on the one morning somebody is standing in
--                                 front of it not knowing an injury is a thing you go and answer. The
--                                 bubble is the same widget the plaza's cards used to wear, pinned
--                                 to a control inside a panel instead.
--
--                                 IT NAMES THE PAID ROW, and on this one morning that is the only row
--                                 in the room (ui/panels/ward.lua's rail). The window one beat earlier
--                                 taught BOTH ways out and did not rank them, which is right -- the
--                                 choice is the room. This instruction is not the room, it is the
--                                 first morning, and on the first morning the two are not equal:
--                                 resting benches Rowan for Injury.REST_DESCENTS trips and the very
--                                 next thing the city asks for is an expedition of four
--                                 (models/descent.lua's PARTY_MAX) out of a company of three. A coach
--                                 that shrugged here would be teaching the player to walk down a body
--                                 short on the one descent where they cannot yet know that costs
--                                 anything. The purse is 250 at this point and the bone is 40, so the
--                                 press is one the player can always make.
--
--                                 AND IT IS DOWN TO THE PRESS. It carried a second clause -- "resting
--                                 mends it too" -- which was the bubble holding the comparison open
--                                 beside a row the player could still take. The rail took that row
--                                 away for one morning, so the clause described a control that is not
--                                 on screen; the rule it was making sure of is the window's, one beat
--                                 earlier, where it always belonged.
--   mend_rest   ui/panels/ward.lua -- ...and the same bubble on the FREE row, for a purse that cannot
--                                 cover the other one. The campaign cannot reach it today (see above)
--                                 and it is authored anyway, because the alternative is a coached room
--                                 whose bubble points at nothing the day that figure moves -- and the
--                                 lesson would then be unfinishable, since the room holds the player
--                                 until somebody is seen to.
return {
    title = "The City's Instructions",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "{select} to take the stair down.", tag = 1, id = "gate_stair" },
        { "character_rowan", "{select} the Cathedral to mend Rowan's injuries.", tag = 5, id = "ward_card" },
        { "character_rowan", "{select} the Rift. The stair down is inside.", tag = 2, id = "rift_card" },
        { "character_rowan", "{select} {door}", tag = 3, id = "new_door" },
        { "character_rowan", "{select} to mend {who}'s injuries.", tag = 6, id = "mend_row" },
        { "character_rowan", "{select} to rest {who}. The purse will not cover setting the bone today.", tag = 7, id = "mend_rest" },
    },
}
