-- THE ANCIENT STAG: antlers and a herd, which is what a stag is when it is not the Meandering one.
--
-- The apex up the road is the only thing in the rift that is trying to leave
-- (data/characters/character_meandering_stag.lua): it cannot strike anything ever, it spends every
-- turn putting ground between itself and you, and the fight is a chase. **None of that is here, and
-- none of it should be.** That animal's premise is its own. What the two share is a FAMILY, and the
-- family has two marks -- a rack, and the healing around it. This body has both, at road scale.
--
-- IT SWEEPS. weapon_stag_antlers hits a three-wide rank, which is the antler contract both other
-- antlered bodies in the game already declare (Hoarfrost Antlers freeze a rank, the Antler Crown
-- charms one). This is the tier-2 member: the family's reach, no rider, and a per-body number under a
-- jab's -- so against one target it is the weaker weapon and against three it is the reason you do not
-- line up. The counterplay is the oldest one in the genre and needs no teaching.
--
-- IT THROWS WHAT REACHES IN. trait_antler_toss rides the rack: strike it from an adjacent tile and the
-- head comes up under you, and you pay for wherever you come down. It is trait_shield_shove's instinct
-- without the shield -- one tile instead of two, an attack only rather than any arm that reached in --
-- because a guard drives you off and an animal only makes room.
--
-- AND IT HEALS WHILE THE HERD IS WITH IT. utility_herd_warmth pays a little health every tick the
-- bearer has an ally beside it, and nothing at all alone. That is the apex's healing arriving by the
-- OPPOSITE VERB: that one heals by walking and heals whoever is standing on what it left, this one
-- heals by standing still and heals only itself, which gives encounter_the_herd its shape: break them
-- apart, or put one down before the rest close.
--
-- IT APPEARS IN EXACTLY ONE ENCOUNTER NOW. There were two -- a lone animal on the road and the herd --
-- and they were one CAST at two counts, which is a fight met twice rather than two fights. The lone
-- stop was the half that went: it rated 582% against Muster.WALK_OVER of 200, so every marker it drew
-- went calm and it offered to resolve itself instead of opening a board. The rule above is exactly why
-- the deletion cost nothing -- warmth is worth zero to an animal on its own, so everything this body
-- can do it can only do here.
--
-- IT DOES NOT BITE, AND IT NEVER DID. This was the last body in the game on weapon_fangs -- a
-- blueprint authored for the wolves whose flavor line still says so -- which weapon_tusks.lua flagged
-- in its own header when it took the boar off the same item. The retag is the half that was quietly
-- broken: nothing in this game carries a `bite` resist, so for as long as this animal bit you its
-- ordinary blow was a melee attack no coat could answer. Two bodies were doing that; now none are.
--
-- NO FERAL INSTINCT. The melee counter is the shared wilds package (boar, bear, every wolf), and the
-- rack is a better version of the same instinct with the animal's own name on it. Carrying both would
-- be two reflexes answering one blow.
--
-- NO `ai` RULE. The one this file used to carry -- press the foe closest to falling -- was the boar's,
-- copied under a different comment, and data/characters/character_boar.lua's header names that copy as
-- the thing that made two animals one unit with different numbers. A sweep does not want the weakest
-- foe, it wants the most bodies, and that is a fact about the footprint rather than a rule anybody can
-- restate here without the two copies drifting.
--
-- `boss = true` IS THE QUEST'S, not the rung's. The Lodge's opener marks this body as The White Stag
-- and wins by assassinating it (quest_hunters_lodge_slot_01), so it stays off the execute and Charm
-- tables. Worth knowing that encounter_the_herd fields three or four of them -- rolled, so it is not
-- the same number twice (models/band.lua) -- and every one inherits
-- that immunity -- a real consequence of a quest flag on a road body, and a design question rather
-- than something to fix quietly here.
return {
    name = "Ancient Stag",
    race = "beast",
    tier = 2,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm -- see the header
    sprite = "assets/chars/stag.png",
    stats = {
        health = 62, mana = 30, stamina = 15,
        damage = 15, magicDamage = 12,
        defense = 4, magicDefense = 9,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Hide stretched over a frame built to take a rival's charge head-on, every autumn, for years.
    --   Built to take it from the FRONT. A point that does not come from the front finds a lean animal.
    --
    -- DELIBERATELY THE APEX'S LINE REVERSED, and kept that way. The Meandering Stag turns points aside
    -- and folds to weight (`pierce = 3, impact = -4`) because it is nine winters old at the end of a
    -- hard autumn -- a frame that is mostly legs. This one is in its prime and in the rut, and the
    -- puzzle a player solves in front of it is the other one. Two stags that answered every coat
    -- identically would be one animal twice. armor_bellowhide is this line, worn.
    resist = { impact = 3, pierce = -3 },
    startingItems = { "weapon_stag_antlers", "utility_herd_warmth" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md), ordered by depth, which is this system's rarity: the print
    -- you meet, the rule, and the chase. None of it is the animal's own kit -- the rack and the herd
    -- are `class = "creature"` and carry no axis at all, so neither the drop pool nor a counter can
    -- mint them -- these are the three things this fight IS, rebuilt as gear somebody could carry.
    --
    -- The hide is the resist line above, tanned. The Close Herd is the herd's rule, learned rather than
    -- looted (the same split Feral Instinct and the Reprisal Quiver already are). The Lowered Crown is
    -- the rack's reflex in a charm cell, which is the slot a shield could never reach.
    drops = { "armor_bellowhide", "utility_the_close_herd", "utility_lowered_crown" },
    -- Named so the fallback is the rack rather than whatever the grid happens to list first.
    defaultAction = "weapon_stag_antlers",
    -- The default posture, stated rather than inherited: it goes at whoever is in front of it, which
    -- for a body whose blow is a rank is the same as going where the most of them are. See the header
    -- on why there is no rule list under this.
    archetype = "aggressive",
}
