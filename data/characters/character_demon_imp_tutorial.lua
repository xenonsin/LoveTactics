-- The Ember Newt: a hand-long salamander of floor one's wood that spits embers, and the first thing
-- anyone in this game kills. Act 0's opening fight fields five of them (states/prologue.lua), and
-- their entire job is to be a lesson rather than a threat -- see data/tutorials/village.lua.
--
-- (THE ID STILL SAYS `demon_imp`, and the body is not one. Act 0 moved onto floor one, whose bodies
-- are beasts, and the Demon Champion is meant to be the ONE demon the player meets there -- a
-- surprise. So this body was renamed in place: the id, the file and the sprite path stay, because the
-- prologue, the encounters and the specs all name it by them.)
--
-- ACT 0 OWNS THIS BODY, and the `_tutorial` on the filename is the whole point of it. Nothing outside
-- the prologue fields a newt: the opening fight, the two survivor stops
-- (data/encounters/encounter_survivors_*.lua) and one body standing beside the Champion, and that is
-- the list. So the numbers below answer to the lesson and to nothing else, which is a promise the
-- suffix makes to whoever re-tunes the rift next.
--
-- IT USED TO BE `character_demon_imp`, an unsuffixed body that read as general-purpose stock, and that
-- is exactly how it went wrong. On 2026-09-22 the Lust honour guard lost its own chaff and the
-- Suppliant's phase reached for the nearest surviving body to summon -- which was this one
-- (data/items/utility/utility_offered_nothing.lua). One blueprint was then serving a level-1 lesson
-- and a deep-floor boss phase at once, and the two want opposite things from every line of it.
--
-- Every number here is tuned against the avatar's opening kit, and they are tuned TIGHT:
--
--   * health 14 dies to one strike of the starting iron sword. The blow is power 6 + Damage 16 - the
--     2 defense below - the 2 `slash` this body's hide turns aside = 18, which is what lets the very
--     first step of the lesson be "swing, and watch it fall" instead of "swing three times".
--   * ...and to one Clear Out (data/items/ability/ability_clear_out.lua), which is the last step:
--     power 12 + the same Damage, 24 after the same two subtractions, to everything standing next to
--     you.
--
-- SO THE MARGIN IS FOUR, and the resist line is half of why. It used to be read as six here, which was
-- true when the header was written and stopped being true when a creature started wearing the coat it
-- was born in (54517935 gave this body `slash = 2`): the same stroke that measured 20 measures 18 now.
-- Nothing downstream noticed, because four is still a kill -- which is the honest shape of this kind of
-- drift. It does not break the lesson, it just quietly spends the room the lesson had.
--
-- `scaling = false` IS WHAT ACTUALLY HOLDS ANY OF THAT, and it is new. Growth.combatantLevel grows
-- ordinary stock toward the player's own level, and this body was ordinary stock: measured, 14 health
-- at party level 3, 18 at 4, 26 at 6, 42 at 10. Against an 18-damage sword the very first lesson in
-- the game therefore stopped being true somewhere around party level 4 -- the newt ate the stroke and
-- stood there, and the step that says "swing, and watch it fall" had nothing to show. The lesson's own
-- arithmetic must not be a function of who walks into it, so it is pinned at blueprint level the way
-- the boar beside it already was, for the same stated reason: a body whose precise numbers are
-- load-bearing rather than merely tuned. tests/tutorial_spec.lua pins the kill; the prologue-scaling
-- case in tests/enemy_scaling_spec.lua pins the pin.
--
-- So a change to the sword, to Clear Out, or to these two lines breaks the prologue's whole shape. The
-- heavier Cinder Boar (data/characters/character_demon_grunt_tutorial.lua) is what the wood fields
-- once the teaching is over.
--
-- IT SPENDS MANA TO ATTACK: its Cinder Spit is the ember in its throat, and the pool below buys
-- exactly that -- 30 mana against a 5-mana shot, which is six of them and no more, because mana never
-- regenerates (Combat.regenerate). A newt that has spat six times has spent itself: the AI drops it to
-- the free unarmed bite, which means walking into sword range, which is how an emptied newt dies. That
-- is the intended arc rather than an oversight -- outlasting it is a real way to beat it.
--
-- Its stamina stays where it was and now pays for nothing but that bite and any answer it throws
-- (Trait.answerCost). The pool is small and that is correct: a newt out of embers is out of arguments.
return {
    name = "Ember Newt",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/demon_imp.png",
    revivable = false, -- a lesson's chaff, not a body to nurse: no downed window, and no revive takes it
    -- Blueprint-exact forever, the same pin the boar beside it carries and for the same reason: the
    -- first step of the first lesson in the game is one stroke and a body falling, and a health pool
    -- that tracks the company turns that into "swing three times" with no line anywhere admitting it.
    -- See the header for the measurement that made this necessary rather than tidy.
    scaling = false,
    stats = {
        -- 30 mana = six Cinder Spits (5 each). Not a number the growth tables ever move: a beast has
        -- no class, so it grows on the neutral (fighter) table, which gains health, damage and stamina
        -- and no mana at all -- so a scaled newt hits harder with the same six shots. That is the right
        -- shape for a shot count, and it means a Drain Mana is worth the same fraction of a newt at
        -- every level of the game.
        health = 14, mana = 30, stamina = 8,
        staminaRegen = 2,
        damage = 4, magicDamage = 10, -- it spits embers; the bite is for show
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
    --   Scaled hide like cracked leather, and the first thing anyone in this game learns not to bother
    --   cutting. It is also the first thing anyone learns to put a spear through.
    resist = { slash = 2, pierce = -2, fire = 2 },
    -- Its body IS its weapon, and that weapon deliberately keeps its distance (see the file).
    startingItems = { "weapon_cinder_spit" },
    defaultAction = "weapon_cinder_spit",
    -- Basic tactics (models/ai.lua): even the runt spits at the softest thing standing. Press the foe
    -- already closest to falling. (The prologue's scripted opening still drives the tutorial newts;
    -- this is what they do once off the leash.)
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
