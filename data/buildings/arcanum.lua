-- THE ARCANUM: the mages' house, the bestiary, and the room where a body is given a job.
--
-- ITS SHELF is staves, foci and the reading that makes them work, deepening as the roster's mage level
-- climbs (Quest.shelfRung) rather than opening whole.
--
-- AND ITS TWO OTHER ROOMS WERE NEVER CARDS, which is why this house takes them. Six plaza buildings
-- folded into seven houses; this was the seat left over, and filling it from the plaza would have meant
-- double-homing a room somebody else had a better claim on.
--
--   THE BESTIARY was a panel on the RIFT screen -- which is supposed to be a hole in the ground and a
--   look at the company, and nothing else (states/gate.lua's header argues this at length about the inn,
--   the store and the hiring hall). A catalogue of what is down there is a thing you read in a library,
--   not at the top of a stair you are about to walk down.
--
--   THE ROLL WAS MEANT TO COME HERE TOO AND DID NOT, which is worth recording because the argument for
--   it still stands and the obstacle is mechanical. Pride's house is where you decide what to become,
--   and ui/class_editor.lua already walks a body from the Armory to its trainer -- but ui/panels/party.lua
--   builds `self.modes` with "loadout" hardcoded first, so a Jobs-only room is not a thing that panel can
--   be asked for. What it would open is the Armory again under another name, and the Armory's own
--   blueprint argues that what a member carries and what a member IS are one question asked twice, kept
--   deliberately in one room. Splitting that needs the panel to learn a mode list, not a new door.
--
-- THE BOOK WAITS FOR THE FOURTH TRIP HOME. A catalogue with nothing in it is a room opened before there
-- is anything to read in it; by the fourth trip something down there has killed the company or nearly
-- done it, and "what WAS that" is a question the player actually has.
--
-- IT IS DELIBERATELY THE LIGHT ONE, and it sits where it does for that: a read-only room, no currency
-- and no commitment, landing the trip after the forge -- which is the heaviest lesson the city has.
return {
    name = "The Arcanum",
    order = 9,
    x = 835,
    y = 480,
    w = 270,
    h = 130,
    vendor = "arcanum",
    -- The desk: what this house says on the way in, and the rooms it offers (models/counter.lua).
    counter = "conversation_arcanum_counter",
    offers = {
        -- QUIET: a class rung stocks this shelf but never puts the card on the plaza. A class level is
        -- a reward the player cannot see, and hanging a door on it put shopfronts in the city that
        -- nobody chose to earn (models/offer.lua's Offer.any).
        { answer = "shelf", panel = "shop", gate = { classLevel = 1 }, quiet = true },
        { answer = "bestiary", panel = "bestiary", gate = { trips = 4 } },
    },
    description = "Staves, foci, a catalogue of what is down there, and what a body may become.",
}
