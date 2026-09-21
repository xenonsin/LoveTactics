-- THE WHITE WOLF: the thing at the top of the pack, and the exact opposite animal to the boar lord.
--
-- THE UNSEEING IS A CORK (character_the_unseeing.lua): movement 2 on a 2x2 body, he does not chase, he
-- never touches you, and his bulk is denial -- the fight is reaching past the clan to get to him. Every
-- number below is the other answer to the same question. She is 2x2 and movement 6. She closes. You do
-- not corner her, you do not outrun her, and her pack arrives while you try. Repeating his shape with
-- fur on it would have been a second boar; this is a different fight built out of the same parts.
--
-- HER DAMAGE IS HER PACK, LITERALLY. weapon_white_wolf_fangs strikes once and once more for every wolf
-- standing within two of her, and ability_howl calls an ALPHA -- so a turn she spends summoning is a
-- turn she spends raising her own attack, and the pack is not a wall in front of the boss, it is a
-- number on the boss's blow. That is the whole fight: the kill order the wolf line has claimed in its
-- comments since encounter_wolf_pack.lua was written, finally true of something.
--
-- WHICH IS WHY 8 AND NOT 17. She was statted at 17 for a single bite. At six bites that is fifty-odd
-- into a mage before armour, which ends a soft body in one turn from full -- so the per-bite figure
-- comes down and the volume carries it. Read the two together or neither means anything.
--
-- AND SHE IS BAD AGAINST PLATE, on purpose. Defense is subtracted from EACH instance of damage
-- (Combat.mitigatedDamage runs per hit), so six bites of 8 lose nearly everything to a bulwark and
-- nearly nothing to a robe. She cannot fight through armour and she erases anything soft, which gives
-- the party something to actually do with its formation instead of one dominant answer.
--
-- 120 HEALTH, UNDER BOTH ROAD APEXES, and the gap is the point. Tier 3's band is 81-154;
-- character_the_unseeing sits at 138 and character_the_winter_hart at 136, and both of those stand
-- still while you hit them. She is much harder to pin, so she is worth less health -- the same trade
-- every fast body in this game makes, made at boss scale.
--
-- STAMINA IS THE FIGHT'S CLOCK. 24 with a regen of 4 against a howl costing 8 means she calls roughly
-- every other turn and bites on the turns between -- and each standing alpha reserves a third of the
-- pool (ability_howl.lua), so two of them and she cannot howl at all until one falls. That reserve is
-- the only ceiling on her pack, and therefore the only ceiling on her damage: it is the dial to turn if
-- this fight ever measures as unwinnable, never a cap on the bite count.
--
-- `boss = true` off the execute and Charm tables (tests/charm_balance_spec.lua). docs/bestiary.md wants
-- that flag narrowed to `assassinate` marks and she is not one -- she is a roaming elite, met on forest
-- ground rather than commissioned. It stays for the reason The Unseeing's stays: a body whose entire
-- fight is the pack must not be turned against your own line or finished with a Coup de Grace, and the
-- flag is the one thing that refuses both.
--
-- WHAT SHE IS KNOWN FOR. None of her own kit can ever drop -- the teeth, the howl and the wood are
-- `class = "creature"`, carry no axis and are `noSteal`/`bound`, so the pool cannot mint them and her
-- fight is never handed to the player as-is (docs/bestiary.md). `drops` are the rebuilds: her voice,
-- her standing, and her teeth, in the order depth can pay for them.
return {
    name = "The White Wolf",
    race = "beast",
    tier = 3,
    boss = true, -- see the header: off the execute and Charm tables
    sprite = "assets/chars/white_wolf.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 120, mana = 0, stamina = 24,
        staminaRegen = 4, -- the howl costs 8; this is what makes it every other turn rather than a cooldown
        damage = 8, magicDamage = 0, -- per bite, and she bites once per wolf with her (see the header)
        defense = 10, magicDefense = 9,
        movement = 6, -- she closes. Nothing this big has any business being this fast.
        speed = 7,    -- second only to the wyrm: she acts before almost anything on the board
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 6, -- an animal that has never once been caught
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The pack's own winter coat, on the animal that has worn it longest: 2 on a grunt, 3 on an
    --   alpha, 4 here -- the ladder read straight down, and stopped where the rung stops. Tier 3's
    --   resist budget is 4 (tests/bestiary_spec.lua), so 5 is not available to her however old she is:
    --   what a deeper body buys is a bigger trade, not a better one, and the negative below is what
    --   keeps it a trade at all.
    --   And the same answer at every rung: weight goes through hide without asking.
    resist = { slash = 4, impact = -4 },
    startingItems = {
        "weapon_white_wolf_fangs", "ability_howl",    false,
        "utility_the_wood_behind_her", "utility_feral_instinct", false,
        false,                    false,              false,
    },
    drops = { "ability_mothers_howl", "utility_the_wood_remembers", "weapon_the_second_bite" },
    defaultAction = "weapon_white_wolf_fangs",
    archetype = "aggressive", -- she comes to you, and she gets there
    -- Basic tactics (models/ai.lua): call while the pack is thin, and otherwise do what every wolf in
    -- this game does -- press the foe closest to falling. The howl's own ceiling is its stamina
    -- reserve, not this rule (see ability_howl.lua on why a count rule is not a ceiling).
    ai = {
        { priority = "high", act = "cast", item = "ability_howl",
          when = { subject = "any_ally", test = "count_at_most", value = 3 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
