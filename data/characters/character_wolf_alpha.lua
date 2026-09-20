-- Enemy character blueprint. A pack leader that joins wolf encounters at higher
-- prestige. See data/characters/bandit.lua for the shape.
return {
    name = "Alpha Wolf",
    kind = "beast",
    tier = 2,
    sprite = "assets/chars/wolf_alpha.png",
    stats = {
        health = 56, mana = 0, stamina = 20,
        damage = 16, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 5,
        speed = 6, -- fastest in the pack
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   The same coat the pack wears, on the body that has kept it longest.
    --   And the same answer: weight goes through hide without asking.
    resist = { slash = 3, impact = -3 },
    -- WHAT MAKES IT AN ALPHA RATHER THAN A BIG WOLF. encounter_wolf_pack.lua has claimed since it was
    -- written that this body gives the fight a kill order -- "the pack is worth more with it alive, so
    -- the correct play is to reach past the teeth in front of you" -- and for a long time that was true
    -- of nothing, because an alpha was a grunt with better numbers. Two items now make it true:
    --   Pack Presence  every wolf within two tiles hits harder, and stops the instant this falls
    --   Howl           a ring of Cowering, which takes the party's movement exactly when the pack is
    --                  kiting them (the teeth give ground out of every exchange)
    -- Both are `creature` kit and unstealable, so neither can ever reach a player's grid.
    startingItems = {
        "weapon_wolf_fangs", "utility_feral_instinct", false,
        "utility_pack_presence", "ability_howl_lesser", false,
        false,                false,                   false,
    },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). Neither entry is a body part -- that rule is absolute, and
    -- the teeth, the instinct, the presence and the voice are all on the far side of it. What is left is
    -- the coat -- a predator's hide that feeds on what it hurts, one rung above the grunt's -- and the
    -- pack's own trick, rebuilt as something a person can wear.
    --
    -- THE CHARM IS THE SHALLOW ONE, AND THAT IS THE GRADER'S CALL RATHER THAN A JUDGEMENT. `. drop-tier`
    -- puts In and Out at depth 2 and the hide at 3, because the instrument reads net stat swing and
    -- replayed damage and this charm moves neither number -- what it actually buys is the counters you
    -- never take, which is worth most against exactly the parry-and-thorns line the deep floors field.
    -- Treat the depth as provisional: models/grade.lua has an authored-grade hatch (see
    -- utility_whetted_vow) for precisely this, a passive the dry run is blind to.
    --
    -- It reads well shallow anyway. You meet this mechanic from the wrong end for a dozen fights -- the
    -- thing that is never there when you swing back -- and then the animal that taught it hands it over.
    drops = { "armor_raveners_hide", "utility_in_and_out" },
    -- Basic tactics (models/ai.lua): the alpha calls the pack onto the wounded -- press the foe closest
    -- to falling. The howl sits above it, because a ring of Cowering is worth more before the pack
    -- closes than after.
    ai = {
        { priority = "high", act = "cast", item = "ability_howl_lesser" },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
