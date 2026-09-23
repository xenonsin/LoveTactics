-- THE LARDER MOTHER: the Giant Spider's alpha, and a rung-1 elite of the wood (encounter_the_larder,
-- billed as a spare in Descent.SINS). NOT the circle's lieutenant -- that seat is Keno's to author.
--
-- She does not chase. Movement 3, a web that brings prey to her, and a Still Hunt that pays for every
-- turn she holds her ground: the fight is meant to come to her, across the densest web in the game (six
-- strands of her own, `seedsGround`, on top of the wood's and her escort's).
--
-- NINE SLOTS, EXACTLY FULL, which is why two mechanics are folded rather than slotted: Liquefy rides her
-- fangs (Digesting, which heals her as it works), and her own web-laying is Cast the Net rather than the
-- line's Spin. Feral Instinct is the one piece of the line she does not carry.
--   Larder Fangs    Digesting + half again on a Rooted body
--   Silk Shot       Root + Halted, from the line
--   Cast the Net    web over a foe and everything around them, catching whoever stands there
--   Strand-walk     to any foe on or beside web, anywhere on the board (clears the Still Hunt)
--   Egg Sac         two Spiderlings, up to four alive; bursts for two more at half health
--   Silkfoot        from the line
--   The Still Hunt  a quarter of Damage per unmoved turn, up to three, spent on the next blow
--   Feels the Web   any foe on or beside web is in range and in sight
--   Moult           once at half health: shed every debuff, step aside, leave the husk
--
-- The counterplay, stated: burn the web (it and she both take fire badly), Cure the Digesting off her
-- victims and she starves, make her move and the Still Hunt is gone, and cut down strands you are not
-- using -- every one left standing is a road she can walk to you.
return {
    name = "The Larder Mother",
    race = "beast",
    tier = 3,
    boss = true, -- the fight is her: off the execute and Charm tables, as the wood's other elites
    sprite = "assets/chars/the_larder_mother.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 134, mana = 0, stamina = 26,
        staminaRegen = 3,
        damage = 14, magicDamage = 0,
        defense = 9, magicDefense = 8,
        movement = 3, -- she does not chase; the web brings them
        speed = 5,
        skill = 5, luck = 5,
    },
    resist = { pierce = 4, impact = -4, fire = -4 },
    seedsGround = { id = "hazard_web", count = 6 },
    startingItems = {
        "weapon_larder_fangs", "ability_silk_shot",        "ability_cast_the_net",
        "ability_strand_walk", "ability_egg_sac",          "utility_silkfoot",
        "utility_the_still_hunt_beast", "utility_feels_the_web", "utility_moult",
    },
    -- One drop per mechanic of hers a person could carry: the patience, the brood, the senses, the skin.
    drops = { "utility_the_still_hunt", "ability_brood_sac", "utility_tremor_cord", "armor_castoff_coat" },
    defaultAction = "weapon_larder_fangs",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "cast", item = "ability_cast_the_net" },
        { priority = "high", act = "cast", item = "ability_egg_sac",
          when = { subject = "any_ally", test = "count_at_most", value = 3 } },
        { priority = "high", act = "cast", item = "ability_silk_shot" },
        { act = "cast", item = "ability_strand_walk" },
    },
}
