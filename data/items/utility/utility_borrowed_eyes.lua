-- BORROWED EYES: the Hornless Twin's drop, and her gift in the fight. Approved 2026-09-26 ("The Oni of Wrath"),
-- after Re:Zero's hornless sister who sees through the eyes of the creatures around her.
--
-- The bearer cannot be Blinded (`statusImmunity`), and at the top of each of its turns every Invisible foe within
-- 4 is Limned -- lit up for everyone -- which is how "your side sees what you see" is built: the light is
-- the existing reveal, and anyone on the bearer's side can aim at what it shows.
return {
    name = "Borrowed Eyes",
    description = "Cannot be Blinded. At the start of your turn, every Invisible foe within 4 is Limned.",
    flavor = "She has not opened her own eyes in a fight for years. There are always better ones nearby.",
    sprite = "assets/items/utility_borrowed_eyes.png",
    type = "utility",
    tags = { "charm" },
    class = "elementalist",
    unlockLevel = 8,
    unstocked = true,
    statusImmunity = { "status_blind" },
    traits = { "trait_borrowed_eyes" },
}
