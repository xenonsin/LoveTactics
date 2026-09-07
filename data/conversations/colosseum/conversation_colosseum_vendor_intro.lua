-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The shopkeeper greets you and the shopkeeper is the house's own person; the door is open because the
-- company has been fighting in this discipline. See data/conversations/bastion/ for both, and for why
-- Rowan is the only companion a first-visit greeting can carry.
return {
    title = "The Shelf and the Sand",
    cast  = { "colosseum", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "colosseum", "Word reaches this stable before the fighters do. Somebody under your banner has been winning up close.", tag = 1 },
        { "colosseum", "So the shelf is yours. Steel, leathers, and the little cruelties that keep a fighter on the card one more week.", tag = 2 },
        { "character_avatar", "What does the house take for that?", tag = 3 },
        { "colosseum", "Nothing. A house takes a cut and I only take coin. You have no house behind you, which is the best thing about you.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Buy the heavy end of it, {name}. What he calls cruelty is a stun, and a stun is a turn nobody spends on you.", tag = 5 },
        } },
        { "colosseum", "Win loud. The crowd keeps a name, and a name is the one thing here I cannot sell you.", tag = 6 },
    },
}
