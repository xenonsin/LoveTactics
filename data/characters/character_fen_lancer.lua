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
-- ITS IDENTITY LEVER IS ITS OWN PAYOFF (2026-11-19, the creature identity pass). The audit found the
-- lancer's identity existed only through the Tidecaller and the Siren. So the lance now collects on the
-- Wet it lays: a body the point finds already soaked is knocked back a tile (weapon_brackish_lance). The
-- first thrust soaks the rank behind; the second drives it, and on a fen the tile behind is often the
-- channel. Stay dry beside a lancer, or keep dry ground at your back.
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
    -- The race's own plate, and it falls off a body that is not wearing it: a naga already carries
    -- `lightning = -4` and the coat would take it to -8 (tests/naga_spec.lua). Pinned, because no
    -- rule in tools/drop_assign.lua can see that -- the hauberk is knight stock and a lancer is not
    -- a knight, so a re-deal takes it off every time it is not said out loud.
    dropsPinned = { "armor_scale_hauberk" },
    drops = {
        "armor_scale_hauberk",
        "weapon_bellowing_edge",
        "weapon_mired_maul",
        "weapon_slow_verdict",
        "utility_whetted_vow",
    },
    defaultAction = "weapon_brackish_lance",
    signatureWeapon = "weapon_brackish_lance",
    ai = {
        -- 1. Work the body standing nearest the water first. Since 2026-11-19 the lance knocks a Wet
        --    body back a tile, so against a soaked bank this IS a drowning blow; against a dry one it is
        --    the Mere keeping the pressure on, which is where the Undertow wants the company to be.
        { priority = "normal", act = "attack", item = "weapon_brackish_lance", targetPref = "drownable",
          when = { subject = "any_foe", test = "in_reach" } },
        -- 2. Otherwise reach out of the water and hit whatever is on it. The spear's own family rule
        --    puts the Wet on the rank behind without the planner knowing anything about it.
        { priority = "normal", act = "attack", item = "weapon_brackish_lance", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
