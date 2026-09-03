-- The player's created avatar -- the baron of Bellmere's child, the one who walks out of the burning
-- town, and the body the whole game is played as. Not one of the seven (see docs/story.md); has no
-- class of its own and grows into whatever the player casts (Growth.NEUTRAL_CLASS is fighter, the
-- class-less fallback). The blank slate is what the rank buys: a small holding's child was trained in
-- nothing in particular, and the only reason this body can hold a sword is that Rowan taught it.
--
-- THE BODY NOT CHOSEN IS NOT WASTED. Character creation offers two; the other one is Ellis, the
-- sibling standing in the house the prologue burns, whose portrait is resolved off `player.body` in
-- models/conversation.lua's `speaker`. Both sprite sets ship in every save.
-- Starts with a sword and
-- the coat off their own back -- the prologue's overworld leg introduces the remaining item types one
-- at a time.
--
-- The leather is there so the armour slot is not empty on the first Loadout screen the player ever
-- opens. It is also the baseline the movement economy is tuned against: base 4, less the coat's one
-- square, is 3 -- the pace every enemy in the prologue moves at, so the opening fights read fairly
-- while the player is still learning that armour costs pace at all (see armor_padded_vest's header).
--
-- THE STAT BLOCK IS SYMMETRIC ACROSS THE TWO SCHOOLS -- damage equals magicDamage, defense equals
-- magicDefense -- and that is the blueprint agreeing with the paragraph above it. This is the one
-- body in data/characters/ that declares no class and grows into whatever the player casts
-- (models/growth.lua blends the level's gains across the ledger). A lopsided 12/4 opening said the
-- opposite: it handed the player a swordsman and then invited them to become a mage from three
-- points behind, so the first Fireball they ever threw was worse than the sword they were told to
-- put down. A blank slate has to be blank on both sides, or the choice it offers is rhetorical.
--
-- DEFENSE CANNOT MOVE: 8 is what prices the Demon Grunt's claw at the 20 the mana lesson is argued
-- from (data/tutorials/village.lua). The damage halves DID move, from 12 to 16, and the reason is
-- that this body is not only a body -- it is Balance.REFERENCE, the yardstick every enemy blueprint
-- in the game is measured against (models/balance.lua).
--
-- At 12 the swing was 18 (Damage plus the starting sword's power 6), which ranked the protagonist
-- THIRTY-SECOND of the forty-six bodies on their own tier-2 rung -- below Rowan at 24, who walks in
-- beside them, and below every companion they will ever recruit. Measured outward it was worse than
-- unflattering: 36 hits to fell a fighter, 34 to fell a knight, against a Balance.TTK band that asks
-- for 2-4. Subtractive mitigation is unforgiving of a small number, and 18 into 13 armour is small.
--
-- What made that everyone's problem rather than the protagonist's is tools/balance_rescale.lua's
-- third pass, which caps any ordinary body that out-hits the reference at one under the reference's
-- swing. A weak yardstick is therefore not a measurement error that stays put; it is a ceiling, and
-- it got stamped across the early bestiary -- twelve blueprints piled up in the 15-18 band directly
-- underneath this number, which is a cap's fingerprint and not twelve authors agreeing.
--
-- 16 puts the swing at 22, within a couple of points of the knight who starts beside it: the
-- protagonist is no longer the weakest thing in their own party. It does not on its own reach the TTK
-- band against an armoured body -- the armour side of the same subtraction has to come down for that,
-- which is what the rescale's first two passes are for -- and it is deliberately not aimed there alone.
--
-- 16 RATHER THAN THE 18 THIS FIRST LANDED ON, and the ceiling is the prologue, not the ledger. The
-- lesson's closing column is scripted to the point (tests/tutorial_spec.lua): the grunt must survive
-- Rowan's follow-up and fall to the player's stroke. Every point of Damage here costs two points of
-- that window, and the grunt cannot pay for any of it -- it is already at the top of its rung's health
-- band. 16/80 is the strongest pairing the beat has room for, measured across the whole grid rather
-- than reasoned out. See character_demon_grunt.lua.
--
-- The prologue's opening lesson survives intact, which is the constraint 12 was originally held by:
-- 16 + 6 - the imp's 2 defense is 20 against 14 health, so the imp still falls to exactly one stroke
-- (data/characters/character_demon_imp.lua). It falls harder, and that is all.
--
-- The magic half moves with it, because the symmetry above is a promise and not a coincidence.
--
-- The blueprint name is "Stranger": the avatar is nameless until the Colosseum announcer asks, and
-- the typed name is written onto the instance (char.name) then -- see states/prologue.lua and the
-- per-character name override in models/save.lua. Gender (and thus the sprite) is chosen at
-- character creation and set on the instance there (states/character_creation.lua builds it via
-- states/prologue.lua's begin).
return {
    name = "Stranger",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/avatar_1.png", -- default; overridden by the chosen body at creation
    portrait = "assets/portraits/avatar_1.png",
    -- PERSONAL GROWTH: what this body gains a level on top of whatever class it is standing in
    -- (models/growth.lua, Growth.personal -- Fire Emblem's class-plus-character arithmetic, without
    -- the dice). Two points, and they are the character rather than the build.
    --
    -- Endurance, because the blank slate has no gift and that is the point of it: this body was
    -- trained in nothing in particular, walked out of a burning town, and kept walking. It is also the
    -- one table that must stay off the damage exchange -- the avatar is Balance.REFERENCE, so a point
    -- of attack or armour here would move every band in docs/balance.md rather than saying anything
    -- about who they are.
    personalGrowth = { stamina = 2 },
    stats = {
        health = 62, mana = 20, stamina = 15,
        staminaRegen = 2,
        damage = 16, magicDamage = 16,
        defense = 8, magicDefense = 8,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 8,
    },
    startingItems = { "weapon_iron_sword", "armor_leather_armor" },
    defaultAction = "weapon_iron_sword",
    -- Basic tactics (models/ai.lua): the starting instinct under auto-battle -- go finish the foe
    -- already closest to falling before spreading damage around. The player overrides all of this from
    -- the Tactics tab.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
