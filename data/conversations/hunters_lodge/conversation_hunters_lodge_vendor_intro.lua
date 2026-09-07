-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The shopkeeper greets you and the shopkeeper is the house's own person; the door is open because the
-- company has been fighting in this discipline. See data/conversations/bastion/ for both, and for why
-- Rowan is the only companion a first-visit greeting can carry.
return {
    title = "The Hunter's Lodge",
    cast  = { "hunters_lodge", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "hunters_lodge", "There is a hunter in your company. The wood tells us that before you do.", tag = 1 },
        { "hunters_lodge", "The Lodge clears the beasts that would eat your children and feeds your town on what is left. Honest work, honest coin.", tag = 2 },
        { "character_avatar", "Never? Not one day in the year?", tag = 3 },
        { "hunters_lodge", "The wild always makes more game. That is the mercy of it. There is always another beast worth killing.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Take a bow and the traps together, {name}. Half of what they sell here does nothing without the other half beside it.", tag = 5 },
        } },
        { "hunters_lodge", "Draw what you need. Rank up, and one day they carve your name on that wall.", tag = 6 },
    },
}
