-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The shopkeeper greets you and the shopkeeper is the house's own person; the door is open because the
-- company has been fighting in this discipline. See data/conversations/bastion/ for both, and for why
-- Rowan is the only companion a first-visit greeting can carry.
return {
    title = "The Cathedral",
    cast  = { "cathedral", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "cathedral", "There is someone in your company doing the Light's work with no chapel to do it in. Word came up the road before you did.", tag = 1 },
        { "cathedral", "The faithful arm those who purge. Wards, relics, and water that burns what should not be walking.", tag = 2 },
        { "character_avatar", "Do I have to kneel for them?", tag = 3 },
        { "cathedral", "Kneel and the taking is made holy. Stand and it is only a purchase. Both are permitted.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Take a ward, {name}. Ground you have closed is ground nothing crosses, and that is worth more than the sermon attached to it.", tag = 5 },
        } },
        { "cathedral", "The shelf is open. The faith asks only that its gifts be used as it intended them.", tag = 6 },
    },
}
