-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 7 opening (data/quests/colosseum/slot_07_no_third_state.lua's map.objective.opening). Ira
-- speaks -- the pre-echo of the slot-10 confront (colosseum_general_wrath_confront), three quests early
-- and on a clock the player survives. She is scheduled and will be pulled off at the bell. She is
-- briefly reachable, and the discovery is that there is NOTHING to bargain with -- no door left to offer.
--
-- "No third state": the house allows Ira two -- WIN and KILL -- and never a third: no stop, no leave.
-- The one thing she ever wanted was never permitted, and the pact she made for it has sealed even that.
--
-- Write to the same constraints as the slot-10 confront:
--   * She never asks to die. * Never operatic -- quiet, interior. * She CHOSE the pact, for freedom.
--   * A sharp fighter -- she reads the room by weight and skill. * Saber is SYMPATHY, never in the program.
-- This scene should show the player the wall (there is no door left) WITHOUT firing the full slot-10
-- material -- hold the biggest lines back for the finale.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "The Patron on the Card",
    cast  = { "character_general_wrath", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "character_general_wrath", "BEAT: Ira reads them by weight on the sand; notes this bout is on the schedule like any other, and it ends at the bell whatever happens.", tag = 1 },
        { "character_avatar", "BEAT: the avatar tries to speak TO her -- to reach the person, to find a grievance or a name, some way to get her out of this.", tag = 2 },
        { "character_general_wrath", "BEAT: she gives them nothing to bargain with -- not cruelty, there is simply no door to offer her; the house lets her win or kill, and there was never a third thing.", tag = 3 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber tries once, in the plainest terms she has, to reach her -- offers to get her out, somewhere else to be.", tag = 4 },
            { "character_general_wrath", "BEAT: Ira closes the door, gently and completely -- she already found the only other door, and it shut behind her; there is nowhere left to put her. Saber hears it land. (Hold the finale's biggest lines back.)", tag = 5 },
        } },
    },
}
