-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The shopkeeper greets you and the shopkeeper is the house's own person; the door is open because the
-- company has been fighting in this discipline. See data/conversations/bastion/ for both, and for why
-- Rowan is the only companion a first-visit greeting can carry.
return {
    title = "The Crucible",
    cast  = { "alchemist", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "alchemist", "Somebody in your company has been doing the Work. That is the only credential this house recognises.", tag = 1 },
        { "alchemist", "The Crucible refines your gear and brews your medicine. Poison and acid, coatings, elixirs, and auras that lend you what you are not.", tag = 2 },
        { "character_avatar", "Lend it from whom?", tag = 3 },
        { "alchemist", "From a source. Does a formula have feelings? Buy, friend, and be improved.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Buy the tinctures and leave the philosophy on the shelf, {name}.", tag = 5 },
        } },
        { "alchemist", "As you wish. The shelf is open, and improvement is only ever a purchase away.", tag = 6 },
    },
}
