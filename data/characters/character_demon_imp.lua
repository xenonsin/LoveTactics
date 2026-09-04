-- A demon imp: the runt of the Demon Lord's horde, and the first thing anyone in this game kills.
-- The village attack fields three of them (states/prologue.lua), and their entire job is to be a
-- lesson rather than a threat -- see data/tutorials/village.lua.
--
-- Every number here is tuned against the avatar's opening kit, and they are tuned TIGHT:
--
--   * health 14 dies to one strike of the starting iron sword (power 6 + Damage 16 - the 2 defense
--     below = 20), which is what lets the very first step of the lesson be "swing, and watch it
--     fall" instead of "swing three times".
--   * ...and to one Clear Out (data/items/ability/ability_clear_out.lua), which is the last step:
--     the same 20 to everything standing next to you.
--
-- IT USED TO BE EXACT, at 16 against 14, and the margin is now six rather than two because the
-- avatar's Damage came up from 12 to 16 (see character_avatar.lua for why -- it is the yardstick the
-- whole bestiary is capped against, and it was ranking thirty-second on its own rung). The lesson is
-- "one stroke", and one stroke is what it still is. What that widened margin costs is the ability to
-- read this health as a tuned number: at 14 against 20 the imp would survive nothing it survives
-- today, so nothing downstream notices, but a future edit to the sword no longer trips over it.
--
-- So a change to the sword, to Clear Out, or to these two lines breaks the prologue's whole shape. The
-- heavier Demon Grunt (data/characters/character_demon_grunt.lua) is what the horde fields once the
-- teaching is over.
--
-- IT SPENDS MANA TO ATTACK, and it is the purest statement of the demon contract: a demon's BODY is
-- paid for in stamina and its WILL is paid for in mana, and an imp is nothing but will. Its Cinder
-- Spit is hellfire, so hellfire is what the pool below buys -- 30 mana against a 5-mana shot, which is
-- six of them and no more, because mana never regenerates (Combat.regenerate). An imp that has spat
-- six times has spent itself: the AI drops it to the free unarmed punch, which means walking into
-- sword range, which is how an emptied imp dies. That is the intended arc rather than an oversight --
-- outlasting a demon is a real way to beat one.
--
-- Its stamina stays where it was and now pays for nothing but that punch and any answer it throws
-- (Trait.answerCost). The pool is small and that is correct: an imp out of fire is out of arguments.
return {
    name = "Imp",
    kind = "demon",
    tier = 1,
    sprite = "assets/chars/demon_imp.png",
    revivable = false, -- a demon does not come back: no downed window, and no revive takes it
    stats = {
        -- 30 mana = six Cinder Spits (5 each). Not a number the growth tables ever move: a demon has
        -- no class, so it grows on the neutral (fighter) table, which gains health, damage and stamina
        -- and no mana at all -- so a scaled imp hits harder with the same six shots. That is the right
        -- shape for a shot count, and it means a Drain Mana is worth the same fraction of an imp at
        -- every level of the game.
        health = 14, mana = 30, stamina = 8,
        staminaRegen = 2,
        damage = 4, magicDamage = 7, -- it spits hellfire; the claws are for show
        defense = 2, magicDefense = 2,
        movement = 4,
        speed = 2, -- slower than the avatar and Rowan both: the party always opens
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Hide like cracked leather, and the first thing anyone in this game learns not to bother cutting.
    --   It is also the first thing anyone learns to put a spear through.
    resist = { slash = 2, pierce = -2, fire = 2, holy = -4 },
    -- Its body IS its weapon, and that weapon deliberately keeps its distance (see the file).
    startingItems = { "weapon_cinder_spit" },
    defaultAction = "weapon_cinder_spit",
    -- Basic tactics (models/ai.lua): even the runt spits at the softest thing standing. Press the foe
    -- already closest to falling. (The prologue's scripted opening still drives the tutorial imps; this
    -- is what they do once off the leash.)
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
