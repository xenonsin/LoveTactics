-- THE SOW: a 2x2 bear and her cub, and the one boss in this game whose escalation the PLAYER chooses.
--
-- The fight is two bodies doing the same thing at two sizes. She and character_bear both carry
-- utility_the_same_wound, so the cub spends the opening turns teaching you what Fury Swipes is at a
-- scale you can survive -- and then you are holding the decision the fight was built around.
--
-- KILLING THE CUB IS THE OBVIOUS PLAY AND IT IS THE EXPENSIVE ONE. Every fight in this game has taught
-- the player to clear the chaff first; this one charges for it (data/traits/trait_bereaved.lua). Leaving
-- it alive is not free either: the wound is on the BODY rather than private to whoever opened it
-- (status_fury_swipes), so the cub's stacks are hers to spend, and a sow swinging into a knight her cub
-- has been working on all fight is the price of mercy. Two costed roads, which is what makes it a
-- decision instead of a trap.
--
-- WHY SHE IS NOT A SECOND BLUEPRINT. The Unseeing turns into character_the_turning because that body
-- genuinely changes what it can do -- it gets legs and a weapon it never had. A sow who loses her cub
-- does the same things harder, and spending a transform, a sprite and a second file on "harder" would be
-- paying the Turning's price for the Gralloch's effect. She gets angry. She does not become another
-- animal.
--
-- SHE HAS LEGS, AND THAT IS A CORRECTION RATHER THAN A CHOICE. The design she came from gave the bear a
-- leap, and the leap was cut. A compounding passive on a body that cannot close is a passive that never
-- reaches its second stack -- so with no gap-closer in the kit, her feet ARE the kit. Movement 4 on a
-- 2x2 is the whole of it: she is not the Unseeing, who does not chase because a clan does the closing.
-- Nobody does her closing. If the ramp measures weak, this number moves before the stack cap does.
--
-- Her bulk is the second half of that. Four tiles of animal in a forest carve is a corridor closed, and
-- unlike the Unseeing she is walking it toward you -- so the ground the party meant to re-form on keeps
-- being where she already is.
--
-- Tier 3's band is 81-154 health, and 145 sits her at the top of the road's apexes
-- (character_the_unseeing at 138, character_the_winter_hart at 136) rather than with a circle's general.
-- It opened at 130 and was raised by measurement, not by taste: tests/descent_spec.lua rated her floor-10
-- fight at 202% of the company, a hair past Muster.WALK_OVER, which means a company could have declined
-- the fight entirely. A boss the party is allowed to walk past is not a boss.
--
-- `boss = true` keeps her off the execute and Charm tables, as every centrepiece is. The CUB deliberately
-- carries no such flag: it is meant to be killable, cheaply and early, because that is the offer.
return {
    name = "The Sow",
    race = "beast",
    tier = 3,
    boss = true, -- the fight is her: off the execute and Charm tables (tests/charm_balance_spec.lua)
    sprite = "assets/chars/the_sow.png",
    footprint = { w = 2, h = 2 },
    stats = {
        -- 30 against a claw's 12, regaining 4 a tick: she swings, waits about three ticks, swings again.
        -- Faster than the cub's engine (24 at 3) because the ramp is hers to finish and his to start --
        -- but not so fast that the wound never gets a chance to lapse between blows, which is the window
        -- the whole counterplay lives in.
        health = 145, mana = 0, stamina = 30,
        staminaRegen = 4,
        -- 22 against the cub's 19. It has to stay ABOVE his after the road fight's retune pushed his
        -- damage up to shorten an over-long skirmish (character_bear.lua): a yearling that hit harder
        -- than his mother would read as a numbers slip in the one fight built to compare them.
        damage = 22, magicDamage = 0,
        defense = 13, magicDefense = 8, -- the road's most armoured hide; still nothing about magic
        movement = 4, -- nobody closes for her (see the header)
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        --
        -- Skill 4 rather than the cub's 3, and no higher. Fury Swipes counts only blows that LAND, so
        -- every point here is a point off the party's best answer to the ramp; a boss that cannot miss
        -- would delete the one counterplay that costs the player nothing but positioning.
        skill = 4, luck = 4,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The cub's hide, grown four more winters. A spear is still going in and still finding nothing.
    --   And there is that much more surface now for an edge to find, which is how she is killed.
    resist = { pierce = 4, slash = -4 },
    startingItems = { "weapon_great_claws", "ability_overpower", "utility_the_same_wound",
                      "utility_the_year_behind_her" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md). None of it is her own kit -- the claws, the wound and the
    -- Year are `class = "creature"` and carry no axis at all, so the pool cannot mint them and a boss's
    -- whole fight can never be handed to the player. These are the three things this fight IS, rebuilt
    -- as gear somebody could carry.
    --
    -- ORDERED BY DEPTH, WHICH IS THIS SYSTEM'S RARITY. A floor picks a rank before it looks at who died
    -- (Spoils.rankBand), so an item only drops on floors that reach its own `dropTier` -- and that makes
    -- the ORDER of the three numbers the whole of the drop-rate design. The hide is the one you will
    -- see, the claw is the rule, and the pelt is the chase.
    --
    -- AND THE CHASE IS THE ONE THE FIGHT CAN REFUSE TO PAY. The pelt is the CUB's, so a company that
    -- leaves it standing and kills her first never sees one -- it walks off the board instead
    -- (trait_orphaned). Nothing enforces that; it simply follows from who dropped and who left.
    drops = { "armor_winterhide", "utility_knapped_claw", "utility_the_yearling_pelt" },
    defaultAction = "weapon_great_claws",
    archetype = "aggressive",
    -- Basic tactics (models/ai.lua): the same ordinary rule the cub carries, for the same reason. The
    -- planner cannot price a ramp -- AI.scoreCandidate sees stamina and steps -- so the compounding has
    -- to fall out of a bear behaving like a bear, pressing whatever is closest to falling, rather than
    -- out of a bespoke rule written to farm stacks that the scorer would then refuse to take.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
