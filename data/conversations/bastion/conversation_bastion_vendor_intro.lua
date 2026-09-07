-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE SHOPKEEPER GREETS YOU, and the shopkeeper is the house's own person (data/vendors/bastion.lua's
-- `portrait`). Not the companion: fronting each counter with the body its line earns was tried and
-- reversed -- see Shop:drawKeeper. A companion is met on a floor and leaves with you; a shopkeeper is
-- somebody you buy from and keep buying from.
--
-- WHY THE DOOR IS OPEN is the one thing this scene has to say, and it is a real gate rather than a
-- story beat: a house opens at level 1 of its class in any body on the roster (`unlockClassLevel`), so
-- the company has been fighting in this discipline and the house has noticed.
--
-- ROWAN IS THE ONE COMPANION WHO CAN BE STANDING HERE. She is sworn in the prologue
-- (data/player.lua's startingRoster), where every other companion is recruited underground and cannot
-- have been by a first visit -- so hers is the only `has` block a greeting can carry that will ever
-- fire. She is also the mentor, and a house is exactly the thing she has an opinion about.
return {
    title = "Those Who Hold",
    cast  = { "bastion", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "bastion", "Somebody in your company has been fighting the way this order fights. That is the only reason this door is open to you.", tag = 1 },
        { "bastion", "The Watch outfits those who hold. Plate a knight can be found standing in, and shields that outlast the arm behind them.", tag = 2 },
        { "character_avatar", "I hold what's mine. Is that post enough?", tag = 3 },
        { "bastion", "It will do. We do not arm those who run, and you have not run yet.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Take the plate first, {name}! Everything else on that rack only works while you are still on your feet.", tag = 5 },
        } },
        { "bastion", "Hold until relieved, then. The shelf is yours, and the order remembers the ones who stay.", tag = 6 },
    },
}
