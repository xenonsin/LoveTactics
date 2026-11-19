-- THE LESSER ARCHON: the court's filler, on the Crown's floor ("The Crown's Bestiary", slice A, 2026-10-09). A robed
-- soldier of the court, fully humanoid -- the author's note on every Archon: rank shows in the face and the robe.
--
--   MANA EDGE     its blade is cut from its own mana, so its blows land on Magic Defense, not Defense
--                 (weapon_mana_cut_blade, a `magical` blade)
--   SPIRIT BODY   the race: felled, its wisp walks back to raise it (data/races/archon.lua)
--   WISP-CARRIER  its own, since the creature identity pass (2026-11-19): a fallen Archon's wisp within 3 of it,
--                 and nearer to it than to its own body, comes to the Lesser Archon instead -- and arriving, the body
--                 stands at once, wherever it lies (utility_wisp_carrier; models/archon_court.lua). It yields to a
--                 Duke: a wisp in the Duke's reach is the Duke's.
--
-- WHY THE LEVER IS ON THIS BODY. The audit found it dead before either rule mattered: tier 1, 10 health, a blade the
-- Duke shares and a race every Archon wears. The pitch offered two shapes -- a wisp that reaches a Lesser Archon
-- raises at once, or a Lesser Archon that picks a wisp up and carries it to the Duke. The first was built: it rides
-- the `wispGoal` seam the Duke and the Crown already walk wisps on, the wisp's turn toward it is logged and seen on
-- the board, and it makes the cheapest body in the court the one to kill FIRST rather than the one that does not
-- matter. The second needed the planner to carry a body across the board, and models/ai.lua was not to be touched.
--
-- HOW YOU BEAT IT, the review's own: your plate does nothing here. Wear a magic ward, or put your spell-hardened
-- bodies in front. And now the order: kill the Lesser Archons before the court's heavier bodies, or every wisp you
-- throw has a short walk home.
--
-- ON THE PRIEST TABLE, like the whole court, and it was measured into it. Its blade scales on Magic Damage, which the
-- classless fallback never grows; the mage table does, but it also grows Defense a point a level, and at the floor's
-- level 35 that made a chaff body plate-proof -- the Lower Court ran 38 unit-turns against the skirmish budget of 22.
-- The priest table grows the blade and the ward and leaves the body soft to steel, which is the court the review
-- describes. The low base health is the same measurement: a body that is raised once is two bodies' worth of turns.
--
-- It drops the Mana Edge, a Battlemage's.
return {
    name = "Lesser Archon",
    race = "archon",
    tier = 1,
    class = "priest",
    sprite = "assets/chars/lesser_archon.png",
    archetype = "aggressive",
    stats = {
        health = 10, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 4, magicDamage = 7,
        defense = 2, magicDefense = 2, -- 4 after the race
        movement = 4,
        speed = 4,
        skill = 4, luck = 3,
    },
    startingItems = {
        "weapon_mana_cut_blade", "utility_wisp_carrier", false,
        false,                   false, false,
        false,                   false, false,
    },
    drops = { "utility_mana_edge" },
    defaultAction = "weapon_mana_cut_blade",
    signatureWeapon = "weapon_mana_cut_blade",
    -- TARGETING (the creature identity pass, 2026-11-19): the court's chaff closes on the nearest body. Its value is
    -- where it stands -- near the court's fallen -- not whom it picks.
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
