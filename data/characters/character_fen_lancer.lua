-- THE MERE, rung 2: the spear that works the bank without ever leaving the water.
--
-- THE FAMILY CONTRACT DOES THE WORK. A spear's effect lands on the FAR tile (docs/weapons.md), so the
-- Brackish Lance skewers the body in front and soaks the rank behind it -- and the Lancer's whole
-- posture falls out of that one fact with no authored tactics beyond "hold the water". It stands in a
-- channel at reach 2 and never has to come out, which on a fen board means it is fighting from ground
-- half the company cannot enter at all.
--
-- IT IS THE SETUP HALF OF THE FACTION'S ONE SENTENCE -- the lancer soaks, the caller conducts, the
-- undertow drags. The soaking is worth nothing by itself (nothing in this game is hurt by water); what
-- it is worth is the Tidecaller's next turn, and the +6 that a soaked body takes from lightning.
--
-- `class = "fighter"` rather than `knight`, and the reason is arithmetic rather than fiction. The
-- knight table grows damage +1 a level against an enemy scaling of +3, so a level-20 knight-classed
-- lancer cannot hurt an armoured party -- the exact trap `class = "rogue"` sprang on character_bandit.
-- Fighter is Growth.NEUTRAL_CLASS, the table every unclassed body in the folder has silently been
-- growing on, so declaring it costs nothing and says something.
return {
    name = "Fen Lancer",
    race = "naga",
    tier = 2,
    class = "fighter",
    sprite = "assets/chars/fen_lancer.png",
    stats = {
        health = 40, mana = 0, stamina = 20,
        damage = 16, magicDamage = 0,
        defense = 3, magicDefense = 3,
        movement = 4, -- 3 after the race: it is not going anywhere, and it does not need to
        speed = 4,
        skill = 7, luck = 5,
    },
    startingItems = {
        "weapon_brackish_lance", false, false,
        false,                   false, false,
        false,                   false, false,
    },
    drops = {
        "weapon_brackish_lance",
        "armor_scale_hauberk",
    },
    defaultAction = "weapon_brackish_lance",
    signatureWeapon = "weapon_brackish_lance",
    ai = {
        -- One rule, and it is the whole body: reach out of the water and hit whatever is on the bank.
        -- The spear's own family rule puts the Wet where it belongs without the planner knowing.
        { priority = "normal", act = "attack", item = "weapon_brackish_lance", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
