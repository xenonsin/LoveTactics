-- THE FACELESS, rung 2: the line soldier of Envy's seat (approved 2026-10-01..03, "Envy's Bestiary", rounds 1-2).
--
-- A Thousand Faces (the race's organ) and a sword it will barely use: at the bell it is dealt a hand of three
-- faces from the whole bestiary and puts on whichever answers the nearest of the company, and it reads again at
-- the top of every turn. It comes in threes, so one squad can be an orc, an elf archer and a dwarf shield by the
-- second turn -- three hands, nine possible bodies.
--
-- IDENTITY LEVER (creature identity pass, 2026-11-19): BRING. Its identity was borrowed -- the player only ever
-- reacted to whatever face it read -- so the race now carries a constant tell: an impact blow that wounds it knocks
-- the face off, and it fights in its own grey body, Unmasked, until its turn ends (trait_a_thousand_faces,
-- Faces.knockOff). "Bring a club" is an answer under every face. TARGETING: nearest, in its own body -- the face it
-- was wearing was chosen to answer the nearest of the company, so bared it goes for that body. (A face brings its
-- own tactics with its grid; this rule is the one it falls back to Unmasked.)
--
-- It drops Borrowed Face, the trick lent to a ninja.
return {
    name = "Faceless",
    race = "faceless",
    tier = 2,
    class = "fighter",
    sprite = "assets/chars/faceless.png",
    archetype = "aggressive",
    faceHandSize = 3,
    stats = {
        health = 46, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 9, magicDamage = 0,
        defense = 3, magicDefense = 3,
        movement = 4,
        speed = 3,
        skill = 4, luck = 4,
    },
    startingItems = {
        "weapon_iron_sword", false, false,
        false,               false, false,
        false,               false, false,
    },
    drops = { "ability_borrowed_face" },
    defaultAction = "weapon_iron_sword",
    signatureWeapon = "weapon_iron_sword",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
