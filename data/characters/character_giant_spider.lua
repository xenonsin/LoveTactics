-- GIANT SPIDER: Gluttony's trapper. Every animal in the wood hunted by closing on you until this one;
-- the spider is the half of the hunt that waits. The web is already down when the fight opens -- the
-- wood's own strands, plus the three this body brings (`seedsGround`, laid by models/arena.lua in the
-- gap between the lines) -- so which lane to cross is the first decision, made at deployment.
--
-- THE LINE, each rung the one below plus one sentence (the succubus line's rule):
--   Spiderling          it bites, and the brood feeds on its own dead
--   Giant Spider        it strings the glade, and its silk takes your legs and your hands for a turn
--   The Larder Mother   ...and she feels every strand, travels them, and eats what she catches later
--
-- THE KIT, and what each piece is for:
--   Spider Fangs   Poison, and half again as hard on a Rooted body -- it fights what is stuck
--   Silk Shot      Root + Halted on a foe in sight: the web catches who walks in, this who stayed off
--   Spin           three strands across the approach: a strand breaks after one catch, this restrings
--   Silkfoot       walks its own web, and acts sooner standing on it
--   Feral Instinct the wood's shared animal passive
--
-- Soft for its rung (the bear is 46 and armoured all over): the web does the work, and fire burns both
-- the web and the spider. Pierce shrugs off the arrows a company opens with; weight goes through it.
return {
    name = "Giant Spider",
    race = "beast",
    tier = 2,
    palate = "ability_silk_shot", -- what Gula takes when she eats one (models/palate.lua)
    sprite = "assets/chars/giant_spider.png",
    stats = {
        health = 42, mana = 0, stamina = 22,
        staminaRegen = 3, -- a Silk Shot (10) about every third turn, a Spin (8) between
        damage = 13, magicDamage = 0,
        defense = 5, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 4, luck = 5,
    },
    -- Pierce resisted, impact through it, and fire the price -- the silk it is made of burns.
    resist = { pierce = 3, impact = -3, fire = -3 },
    -- Three strands of its own, laid before the bell between the two sides (models/arena.lua).
    seedsGround = { id = "hazard_web", count = 3 },
    startingItems = {
        "weapon_spider_fangs", "ability_silk_shot", "ability_spin",
        "utility_silkfoot",    "utility_feral_instinct", false,
        false,                 false,                    false,
    },
    -- WHAT IT HANDS OVER, each one of its own mechanics rebuilt for a person (docs/drops.md -- never a
    -- body part): its feet as the Gossamer Mantle, and the line it pays out behind it as the Dragline.
    -- The Silk Shot has no drop of its own on purpose -- the Poacher's Bolas is the same knot, and it
    -- stays on the Poacher's counter rather than coming off a spider.
    drops = { "armor_gossamer_mantle", "ability_dragline" },
    defaultAction = "weapon_spider_fangs",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "cast", item = "ability_silk_shot" },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { act = "cast", item = "ability_spin" },
    },
}
