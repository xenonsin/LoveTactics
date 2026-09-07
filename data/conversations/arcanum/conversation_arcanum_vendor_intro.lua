-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The shopkeeper greets you and the shopkeeper is the house's own person; the door is open because the
-- company has been fighting in this discipline. See data/conversations/bastion/ for both, and for why
-- Rowan is the only companion a first-visit greeting can carry.
return {
    title = "The Arcanum",
    cast  = { "arcanum", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "arcanum", "Somebody in your company has been working. Practice leaves a mark, and this house is built to read it.", tag = 1 },
        { "arcanum", "The Arcanum wins the wars the crown cannot. Elements, wind-ups, hazards laid on a tile and left standing there.", tag = 2 },
        { "character_avatar", "Everything here was made by somebody.", tag = 3 },
        { "arcanum", "By somebody, yes. Does it matter who, so long as it works? No one else can do what we do.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Buy the long spells, {name}. A wind-up costs a turn you were going to spend anyway.", tag = 5 },
        } },
        { "arcanum", "The shelf is open. We ask only that what we sell be used as we intended, and we always know when it is not.", tag = 6 },
    },
}
