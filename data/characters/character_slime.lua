-- THE SLIME: the one body on the roster that a melee company cannot hurt at all.
--
-- Every other creature in data/characters/ is a question about which weapon you brought
-- (docs/bestiary.md, "what a creature wears instead of armour"): a wolf's coat turns a blade and
-- folds to a mace, a demon's plate the other way round. Those are all the same question at different
-- angles, because a subtractive resist floors at 1 and a scratch is still a hit. This one asks a
-- different question, and it asks it categorically -- there is nothing in here for an edge to part,
-- for a point to find, or for a head to break. Steel is not a small answer to a slime. It is not an
-- answer.
--
-- WHAT IS AN ANSWER IS AN ELEMENT, once. The body takes the first element it is shown into itself:
-- proof against that element from then on, and striking with it (data/traits/trait_adaptive.lua, on
-- the bound Amorphous Body). So the fight is a rhythm rather than a wall --
--
--   throw fire      it burns, and stops burning
--   throw fire      nothing, and you have spent a turn
--   throw ice       it lands, the fire memory is gone, and now it hits you with cold
--
-- -- and the party that answers it is the party carrying two elements, not the party carrying the
-- biggest one. That is the whole design: this is a loadout question asked in a shape no coat can ask
-- it, and it is why the adaptation strips the old element instead of stacking a new one on top.
--
-- AND A BRANDED BLADE WORKS, which is the clause that keeps the lesson from being a trap. An item's
-- immunity is answered by any element on the blow (models/status.lua), so the Dawn Chrism's holy, a
-- Battlemage's Resonant Grip and a demon's burning claws all reach it -- a physical blow carrying an
-- element is an elemental blow, and docs/bestiary.md already says so in the other direction. "Put
-- fire on your sword" has to be allowed to be the obvious answer, or the body punishes the player for
-- working it out.
--
-- A SET-PIECE, AND IT WAS AUTHORED AS ORDINARY TRAFFIC UNTIL THE MEASUREMENT SAID OTHERWISE. The
-- intent was right -- the rule should be learned somewhere cheap before the King charges for it --
-- and the shelf was wrong: tests/skirmish_spec.lua autobattles every `kind = "combat"` stop and holds
-- it to 22 unit-turns, and a trio of these took 56. Three bodies a melee line cannot hurt is a long
-- fight by construction, and there is no count or health figure that fixes it without deleting the
-- puzzle.
--
-- So the fen deals it as an ELITE (data/encounters/encounter_fen_ooze.lua): a marked stop the player
-- reads off the board and decides about, rather than something that jumps them in a corridor. Cheap
-- is still the intent -- it is met eight floors above the crowned version and pays a fraction of what
-- that one does -- but cheap now means "you chose this", not "it was short".
--
-- SLOW, and that is the balance rather than the health. A body the party cannot answer with steel and
-- cannot outrun would be an attrition sink with no decision in it; one that moves three and swings at
-- speed 6 can be walked away from while the caster reloads, which is what makes "who has an element
-- left" a question the board asks rather than a sum.
return {
    name = "Slime",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/slime.png",
    stats = {
        health = 46, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 13, magicDamage = 0,
        -- Low on both, and on purpose: its defence is categorical, not arithmetic. Stacking armour on
        -- top of an immunity would make the elemental answer feel bad as well as mandatory.
        defense = 2, magicDefense = 2,
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 2,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --
    -- NO PHYSICAL LINE, which is the one body in the folder where that is a statement rather than an
    -- omission: the redistribution rule exists to make a creature answer a sword differently from a
    -- mace, and this one answers them identically by answering neither. The trade is made in the
    -- elements instead, where the fight actually happens.
    --   It is the corrosive thing in the room. Acid is what it is FOR.
    --   Cold is the one element that does not have to get through it -- it only has to stop it moving.
    resist = { acid = 3, ice = -3 },
    -- Its loadout as the 3x3 grid (row-major; false = empty). The Amorphous Body is bound in the
    -- centre and is not a thing it holds -- it is the thing it is; the pseudopod is what it does with
    -- itself. Two items, which is the creature shape: a natural weapon and its own rule.
    startingItems = {
        false, "ability_corrosive_touch", false,
        "weapon_pseudopod", "utility_amorphous_body", false,
        false, false,                     false,
    },
    defaultAction = "weapon_pseudopod",
    -- WHAT IT IS KNOWN FOR (docs/drops.md). Neither the pseudopod nor the Amorphous Body is on it --
    -- that rule is absolute, and both are on the far side of it, unstealable and on no shelf.
    --
    -- THE FICTION IS THE MECHANIC, WORN. What comes back out of a slime is what its insides could not
    -- get through, and the three coats below are the only things in the catalogue that qualify: each
    -- one DRINKS an element and does nothing whatever about anything else, which is the slime's own
    -- verb and the slime's own bargain, sold over a counter. A leather coat does not come out of one.
    -- A Salamander Hide does, because fire could not get through it either.
    --
    -- It is also the most useful thing this body could possibly hand a player, and that is deliberate
    -- rather than generous: the lesson the slime teaches is BRING AN ELEMENT, and the reward for
    -- learning it is the wearable half of the same idea. Three of them, one per element family, so the
    -- list is a set rather than a pick.
    --
    -- The prism is glass and is about elements; the mail is the chase, and it is the slime's own read
    -- made wearable -- hit it and it answers. Depths 2, 2, 2, 4, 6 (Spoils.depthOf, which lifts a
    -- discipline's stock above its own dropTier), against a combat band that runs 1-2 at the shallow
    -- end and 5-6 deep, so the body pays its own at every depth it is met at.
    drops = {
        "armor_salamander_hide", "armor_rimecloth", "armor_stormcloth",
        "utility_resonance_prism",
        "armor_spike_mail",
    },
    -- Basic tactics (models/ai.lua). It still has no plan -- the posture's own approach, walk at the
    -- nearest thing and lean on it -- plus exactly one rule, and that rule is not a second puzzle
    -- stapled to the first. It is the SAME puzzle made literal: the body's whole sentence is "your
    -- steel does not work here", and corroding the steel is that sentence spoken out loud
    -- (data/items/ability/ability_corrosive_touch.lua).
    --
    -- Gated on the target being ADJACENT rather than merely existing, because the cast is range 1 and
    -- a slime that spent its turn winding up a touch it could not reach would be a body doing nothing
    -- while the party walked away -- which is the counterplay working by accident instead of by
    -- choice. It corrodes what it has already caught up with.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "cast", item = "ability_corrosive_touch",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
