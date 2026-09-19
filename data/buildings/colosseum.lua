-- THE COLOSSEUM: the fighters' house, and the city's only door onto somebody else's company.
--
-- ITS SHELF is what wins fights, sold by the people who win them, and it deepens rung by rung as the
-- roster's fighter level does (Quest.shelfRung) rather than opening whole.
--
-- AND ITS SECOND ROOM IS THE SAND. The Dueling Grounds stood on the plaza as a card of its own and was
-- the only door in the city that named somebody ELSE'S errand -- it kept no shelf, posted no work, and
-- unlocked on `quest_colosseum_slot_01`, which is this house's own first posting. A card that exists to
-- point at another house is a card that belongs inside it. The gate is unchanged: stand on the sand
-- once, in the fight Saber posts on a floor, and the match is on the desk ever after.
return {
    name = "The Colosseum",
    order = 2,
    x = 175,
    y = 120,
    w = 270,
    h = 130,
    vendor = "colosseum",
    -- The desk: what this house says on the way in, and the rooms it offers (models/counter.lua).
    counter = "conversation_colosseum_counter",
    offers = {
        -- QUIET: a class rung stocks this shelf but never puts the card on the plaza. A class level is
        -- a reward the player cannot see, and hanging a door on it put shopfronts in the city that
        -- nobody chose to earn (models/offer.lua's Offer.any).
        { answer = "shelf", panel = "shop", gate = { classLevel = 1 }, quiet = true },
        -- Saber's posting is still the deed that opens it -- the sand is where a duel comes from, and
        -- until somebody HAS a name there is nobody for another house to be matched against. The trip
        -- count behind it is a backstop, not a second route worth taking: a player who never takes her
        -- posting still gets the room, last of all, because PvP is the one door the core loop does not
        -- need and the only one that opens onto a whole other mode.
        { answer = "duel", panel = "pvp",
          gate = { any = { { quest = "quest_colosseum_slot_01" }, { trips = 6 } } } },
    },
    description = "Blood and sand, and a card posted for anyone who wants a name.",
}
