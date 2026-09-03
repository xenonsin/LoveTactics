-- A lesser demon: the antagonist the prologue introduces, and the step UP from the imps that open
-- the village attack (states/prologue.lua). Where an imp dies to one blow, this takes five between
-- two people -- it is the first thing in the game that has to be fought rather than swatted.
-- The Demon Lord it serves is named in the scene, not met (see docs/story.md).
--
-- ITS 74 HEALTH IS SPENT EXACTLY by the prologue's closing beat, and the whole column is written out
-- in data/tutorials/village.lua (under `spawn`) with tests/tutorial_spec.lua pinning it. The short
-- version: the lesson's last lesson is the turn order, so the grunt has to survive a parry, a mace,
-- and a Jolt still standing and still dangerous -- and then fall to exactly one blow each from Rowan
-- and the player, which is what the Jolt's stun buys them. Re-tune this and that beat stops landing.
--
-- WHICH IS WHY IT IS THE ONE BODY THE HEALTH REBALANCE SKIPPED. Every other character in data/characters/
-- had its pool cut to roughly 0.7 of what it was, to bring the hits-to-kill down across the game; this
-- one could not go with them. Its health is not a balance number at all -- it is the SUM of five
-- authored blows plus the sliver the last one is meant to leave. Cut it to 0.7 with everything else
-- and the choreography kills it on Rowan's second swing, a full beat before the player's own finishing
-- stroke, which is the one thing the whole prologue is built to hand them. So it is deliberately the
-- sturdiest common enemy in the game. In the siege encounters that field it in packs
-- (data/encounters/encounter_siege_*.lua) that reads as the horde's heavy rather than as an oversight,
-- which is the one place the exemption is actually visible.
--
-- IT WAS 66, and it moved for the reason the paragraph above gives for why it usually does not: one of
-- the five blows changed. The avatar's magicDamage came up to meet its Damage (character_avatar.lua --
-- a class-less body should not open lopsided toward the sword), which prices its Jolt at 14 instead of
-- 6, so the column bills 8 more before the last stroke and the pool follows it. That is the rule
-- working, not an exception to it: this number is downstream of the blows, and it is the only number
-- here that is allowed to be. The residual it leaves for the player's finishing swing is still 6.
--
-- THE DEMON CONTRACT, stated on the body it is easiest to read off: a demon's BODY costs stamina and
-- its WILL costs mana. The claws are the body, so they stay on stamina exactly as they were; the mana
-- below buys Brimstone (data/items/ability/ability_demon_brimstone.lua), the gout of hellfire it
-- spits at the ground to close a lane. An imp is all will and pays for everything in mana
-- (character_demon_imp.lua); the Champion pays for its claws, its riposte and its throw out of
-- stamina, and for the Roar and the Cleave out of mana (character_demon_champion.lua). This body is
-- the middle of that and carries both.
--
-- None of it touches the prologue's arithmetic. The grunt is hand-driven for every turn it takes in
-- the village (data/tutorials/village.lua's `script` -- it charges, it is answered, it holds), so it
-- never reaches for Brimstone there, and the column above is counted in physical blows: its claw
-- against the avatar's Defense, the Jolt against the magicDefense below. `magicDamage` was 0 and is
-- now 6 for one reason -- Brimstone is `magical`, and a gout thrown by a body with no magic behind it
-- would land for nothing and never be worth the mana. Nothing in the prologue reads it.
return {
    name = "Demon Grunt",
    kind = "demon",
    tier = 2,
    sprite = "assets/chars/demon_grunt.png",
    revivable = false, -- a demon does not come back: no downed window, and no revive takes it
    -- Blueprint-exact forever: every other enemy grows with the company (models/growth.lua,
    -- Growth.combatantLevel), but this one's numbers are a LESSON, not a tuning. The prologue's parry
    -- beat needs the claw to land for the avatar's sword to answer, and its stamina is cut to the exact
    -- width of one swing (see below) -- both arguments break the moment the stat block moves. The same
    -- reason its health stayed at 66 through the pass that cut every other pool to ~0.7.
    scaling = false,
    stats = {
        -- Stamina is 15, not the ~0.25 cut the scarcity pass would give it (which was 10). Its Rending
        -- Claws cost 12 to swing (below), so a 10-stamina grunt could never attack at all -- it would be
        -- the one common enemy that stands there inert, and the prologue's parry beat (which depends on
        -- the grunt actually landing a blow for the avatar's sword to answer) would silently break. 15 is
        -- one clean swing with a sliver to spare, matching its bigger sibling the Demon Champion; keep it
        -- at least the claw's cost. See data/tutorials/village.lua's closing arithmetic.
        --
        -- But 15 buys only the FIRST swing, and that is not enough on its own. The claw costs 12, and at
        -- the DEFAULT 1/tick regen (Combat.DEFAULT_STAMINA_REGEN) a grunt recovers only ~6 stamina across
        -- the ~6 ticks its speed-6 claw bills to the timeline -- never the 12 it needs -- so after the
        -- opening blow it can no longer afford its own weapon and the enemy AI drops it to the free
        -- unarmed punch (models/ai.lua's itemsFor fallback) for roughly every OTHER turn. In the prologue
        -- it dies before that shows; in the siege/survivor packs that field it for a long fight it read as
        -- "the demon that keeps swatting with its fists." staminaRegen = 2 refills the full 12 across a
        -- claw's own 6-tick cycle, so it swings claws every turn and the fists never come out. Starting
        -- stamina stays 15, so nothing about the prologue's opening arithmetic moves.
        --
        -- 24 mana is three Brimstones (8 each) and then no more for the rest of the battle, because
        -- mana does not regenerate (Combat.regenerate) and `scaling = false` means this pool is the
        -- same three castings at every level of the game. Three is deliberate: enough that closing a
        -- lane is a thing grunts do, few enough that a party can wait one out -- and few enough that
        -- one Drain Mana (data/items/ability/ability_drain_mana.lua) is worth a whole casting.
        -- HEALTH IS THE PROLOGUE'S CHOREOGRAPHY, not a durability knob. The lesson's closing column is
        -- parry, Rowan's mace, the Jolt, Rowan's shove into the top edge, and then the player's last
        -- stroke -- and that ending only reads if the grunt is still standing when the player swings and
        -- falls when they do. tests/tutorial_spec.lua pins the whole window: what is left after the Jolt
        -- must exceed Rowan's follow-up (or she steals the kill) and must not exceed the player's own
        -- swing (or the lesson trails off).
        --
        -- It was 74 against an avatar whose Damage was 12, which left 26 in that window. The avatar's
        -- Damage came up to 16 (character_avatar.lua: it is Balance.REFERENCE, and at 12 it was ranking
        -- thirty-second on its own rung and capping the whole bestiary underneath it), and the same
        -- column then left 18 -- under Rowan's 22 follow-up, so she took the kill and the beat the
        -- prologue is built to end on stopped happening. 80 restores it, at 24 against her 22.
        --
        -- 80 IS THE CEILING, not a chosen number: tests/bestiary_spec.lua holds a tier-2 body to 31-80
        -- health, and the first repair here tried 90 and was caught by it. So the grunt's health and the
        -- avatar's Damage had to be solved together rather than one after the other, and 16/80 is the
        -- strongest avatar this beat has room for -- measured across the whole grid, not reasoned out.
        --
        -- THE WINDOW IS TWO POINTS WIDE and that is the cost of taking the strongest legal avatar. If a
        -- later edit to the sword, the mace, Minor Shock or this line breaks tutorial_spec, do not
        -- nudge blindly: re-measure the grid. Every point of avatar Damage costs two points of window,
        -- so 15 buys four and 14 buys six, and the grunt cannot pay for any of it -- it is already at
        -- its rung's ceiling.
        health = 80, mana = 24, stamina = 15, staminaRegen = 2,
        damage = 8, magicDamage = 6,
        defense = 4, magicDefense = 2,
        movement = 4,
        speed = 2,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 5,
    },
    -- Its body IS its weapon, and that weapon is the point of the thing (see the file). It used to
    -- carry a borrowed iron sword, which cost the prologue twice over: a 6-damage swing at a 62-health
    -- avatar is not a reason to spend a whole mana pool delaying its turn, and the sword's Parry came
    -- along with it, so the blows that end the lesson all answered back.
    --
    -- Brimstone rides beside the claws rather than replacing anything: the claws are what a grunt
    -- wants to be doing, and the gout is what it does when it cannot get there. Its firing rule lives
    -- on the item itself (an item's `ai` block binds to that item -- see AI.rulesFor), so the tactics
    -- written on this blueprint stay the one line they have always been.
    startingItems = { "weapon_rending_claws", "ability_demon_brimstone" },
    defaultAction = "weapon_rending_claws",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
