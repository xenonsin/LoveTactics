-- THE HAWK: the wood's bird, and the Sated's escort. Reviewed over two rounds on 2026-09-23 ("The Sated and
-- the Flight"). Every stealing pitch was denied ("stealing isn't a hawk thing"); what it got was the two
-- halves of a raptor's hunt, both riding its Raking Talons:
--
--   SWOOP     +1 damage for every tile flown this turn before the strike, up to +6 -- and it still flies
--             back to where its turn began, so a hawk that crosses the field hits hard and is gone
--   MANTLING  a strike that leaves its quarry below half does not fly home: it hunches over the body,
--             Roots it and feeds on it every turn, and cannot move or dodge while it eats. Anything that
--             hits the hawk breaks the grip
--
-- THE COUNTERPLAY, STATED: stand where it cannot get a run; and when one mantles a friend, hit the bird --
-- it is the easiest target on the board while it is down on the body. And beside the Sated a mantled body
-- that dies is eaten WITH its hawk.
--
-- SPLIT FROM THE GLOVE'S HAWK in the same review: this blueprint used to be the Falconer's Glove's summon
-- as well, and that bird is character_falconers_hawk now, untouched. Gula's Palate still reads nothing off
-- a hawk ("Gula's taste of the hawk" was denied with the stealing).
return {
    name = "Hawk",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/hawk.png",
    stats = {
        health = 14, mana = 0, stamina = 16,
        damage = 6, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 7, -- the fastest thing on the field, and every tile of it is damage
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Feathers and hollow bone: a blade passes through the shape rather than the bird.
    --   A bird is taken out of the air by a point, which is the whole of why anyone hunts with one.
    resist = { slash = 2, pierce = -2 },
    startingItems = { "weapon_raking_talons" },
    drops = { "utility_hawk_bells" },
    defaultAction = "weapon_raking_talons",
    -- Basic tactics (models/ai.lua): a raptor stoops on the weakest -- press the foe closest to falling,
    -- which is also the one it can mantle.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
