-- A shield, so it swaps Wait into Defend (docs/weapons.md). Its extra is that the brace is a MIRROR:
-- planting it grants status_reflect_physical, so the next single-target physical blow aimed at the
-- knight rebounds onto whoever threw it.
--
-- Quest-only: `class` with no `price`.
--
-- The pair to data/items/weapon/weapon_reflecting_wand.lua, which does the same thing for spells off the
-- mage's shelf. One word -- mirrored -- split across the two schools and the two vendors, so a party
-- carrying both can point it at whichever half of the enemy's kit is worse. That symmetry is the reason
-- neither of them covers both: a shield that turned spells would make the wand pointless and vice versa.
--
-- Against the ordinary Defend it is a bet rather than an upgrade. Bracing gives a knight a flat bonus
-- against everything that lands; this gives them nothing at all against a blast, a hazard or a spell, and
-- returns one big single-target hit in full. So it is the shield for a fight with one heavy attacker in
-- it -- a champion, a boss, a charging greatsword -- and dead weight against a swarm.
--
-- The rebound is not a counter and is priced nowhere: nothing is spent, nothing escalates, and the knight
-- does not swing. It is the attack, arriving at the wrong address.
return {
    name = "Reflecting Shield",
    description = "Replaces Wait with Defend: brace, and the next physical blow aimed at you rebounds onto its attacker.",
    flavor = "The Bastion's smiths insist the finish is functional. Nobody has asked what function.",
    sprite = "assets/items/reflecting_shield.png",
    type = "armor",
    tags = { "shield" },
    class = "knight",
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 } },
    resist = { physical = { 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4 } },
    waitBehavior = {
        kind = "defend",
        speed = 3,
        -- Under a buckler's, and deliberately: the mirror is the sale, and a shield that braced deeply
        -- AND reflected would simply retire the rest of the rack.
        defense = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
        status = "status_reflect_physical",
    },
}
