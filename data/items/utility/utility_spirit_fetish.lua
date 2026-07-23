-- Spirit Fetish: the hunter half of the Shaman (hunter x mage). A charm of bound feathers and bone that
-- lays a heartening zone around its bearer and carries it wherever they walk (data/hazards/hazard_rally
-- .lua -- allies standing in it are Inspired). Its whole point is the Shaman's summoned spirits: a
-- called elemental fights harder standing in its caller's shadow. Borrows the incense machine like the
-- Coveted Blood (docs/classes.md) -- a zone that is wherever the bearer is.
return {
    name = "Spirit Fetish",
    description = "Lays a heartening zone around you that travels with you: allies (and your spirits) beside you are Inspired.",
    flavor = "The wind does more when it remembers who called it.",
    sprite = "assets/items/utility_spirit_fetish.png",
    type = "utility",
    tags = { "charm", "morale" },
    class = "hunter",
    discipline = "shaman", -- hunter x mage; the Spirit-totems mechanic's first stock
    price = 400,
    repRank = 3,
    incense = { hazard = "hazard_rally", radius = 1, amount = { 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6 } },
}
