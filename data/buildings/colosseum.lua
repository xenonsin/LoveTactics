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
        -- THE SHELF OPENS ON THE CITY SCHEDULE (models/offer.lua's Offer.SCHEDULE): one house's shelf per
        -- trip home, in a fixed order, unless a body unlocks this house's class first -- that pulls
        -- the shelf into the next trip's slot. Once open it stays open, and it announces its house:
        -- the plaza grows by one shopfront a homecoming. A class level still buys DEPTH and nothing
        -- else (Quest.shelfRung): level 0 is rung 0, the bottom band.
        { answer = "shelf", panel = "shop", gate = { city = "colosseum.shelf" } },
        -- Saber's posting is still the deed that opens it -- the sand is where a duel comes from, and
        -- until somebody HAS a name there is nobody for another house to be matched against. The posting
        -- is an EVENT on the city schedule (models/offer.lua's Offer.SCHEDULE) and takes a trip's
        -- feature slot ahead of it; trip 6 is the guarantee for a player who never takes her posting.
        { answer = "duel", panel = "pvp",
          gate = { city = "colosseum.duel" } },
    },
    description = "Blood and sand, and a card posted for anyone who wants a name.",
}
