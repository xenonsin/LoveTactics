-- The Bulwark: a shield with a boss on it, carried by knights who would rather move you than hurt you.
--
-- Its EXTRA over the plain buckler (data/items/armor/armor_buckler.lua) is a REFLEX rather than a
-- stance: it carries Shield Shove (data/traits/trait_shield_shove.lua), so anyone who lands a melee
-- blow on the bearer is driven two tiles back. Compare the Oathkeeper, whose extra is `covers` -- it
-- spreads its brace to the line. This one keeps everything to itself and spends it on the one foe
-- foolish enough to close.
--
-- Both are shields, so both swap Wait for Defend; that is the family's mechanic and neither may drop
-- it (docs/weapons.md). What separates the three is what each does BESIDES bracing: nothing (buckler),
-- brace the neighbours (Oathkeeper), shove the attacker (this).
--
-- The shove is what makes it a knight item rather than a fighter one, and the distinction is the whole
-- point of the shelf: it deals no damage at all. What it produces is a foe standing somewhere else --
-- in the fire your mage laid, off the high ground it climbed, back across the spike trap it walked
-- over, or simply out of reach of the archer behind you. "It does not kill you, it decides where you
-- stand" (docs/classes.md), answered without spending a turn to say it.
--
-- It also has a shield's TAG, so a Shield Bash charm beside it in the grid arms off this shield exactly
-- as it would off any other -- a bearer carrying both answers a braced blow with a stun AND a shove,
-- and pays the escalating answer price twice for the privilege.
return {
    name = "Bulwark",
    description = "Replaces Wait with Defend. Melee attackers are driven two tiles back.",
    flavor = "The Bastion teaches the boss before the rim. A door that opens outward is still a door.",
    sprite = "assets/items/armor_bulwark_shield.png",
    type = "armor",
    tags = { "shield" }, -- a Shield Bash charm beside it in the grid can bash with this
    class = "knight",
    price = 620,
    repRank = 3,
    traits = { "trait_shield_shove" },
    bonus = { defense = { 7, 8, 8, 9, 10, 11, 11, 12, 13, 14, 15 } },
    resist = { physical = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 }, impact = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
    waitBehavior = {
        kind = "defend", speed = 2,
        defense = { 8, 9, 10, 10, 11, 12, 13, 13, 14, 15, 16 },
    },
}
