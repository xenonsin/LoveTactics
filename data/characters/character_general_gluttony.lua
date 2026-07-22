-- The general of Gluttony, and the end of the Hunter's Lodge line (docs/story.md, "The Hunter's Lodge").
-- Enemy blueprint; the objective of data/quests/general_gluttony.lua. The finale
-- (data/quests/the_gate_below.lua) already reserves a slot for her -- "general_gluttony" sits in its
-- requiredQuests.
--
-- WHO SHE IS: once the finest hunter the region ever produced, celebrated and real -- and the Grand
-- Hunter turning NOW, the current head of the cull's own harvest. Every Grand Hunter turns; most turn
-- into a mere beast. Gula made a pact with the Demon Lord and did not merely turn -- she became the
-- crowned apex of the apexes, keeping mind enough to go on hunting for the pleasure of it. What the
-- bargain gave her was not strength but APPETITE: the pleasure of the kill made a compulsion that sates
-- less each time and demands the next sooner.
--
-- Her rule rides on the Maw in her grid (a blueprint's own `traits` field is never collected; only an
-- item's is -- models/trait.lua): "never stops" (data/traits/trait_ravenous.lua) -- every blow she lands
-- feeds her. The counterplay is the sin read as tactics: STARVE her -- burst her down, kill clean, deny
-- the long trade. The one hunter she can never feed on is Kaya (character_kaya.lua), who carries no
-- surplus to eat.
--
-- Her kit is the gralloch knife (heal-on-hit, data/items/weapon/weapon_gralloch_knife.lua) and the wolves
-- she calls to the heart of the wood. Statted as the beast at the wood's centre: an enormous health pool,
-- heavy damage, warded in flesh and thin against magic. `assassinate` is the honest objective.
--
-- TODO (see docs/story.md + the plan): the finale is not fully built. She should be TWO-PHASE -- the human
-- huntress sheds into the beast she has been becoming, the thing the Lodge exists to hunt -- and her
-- second-form mechanic is DEVOUR-THE-FALLEN: any downed unit adjacent to her, even her own, consumed to
-- heal her toward full. Both are new work over what ships here.
return {
    name = "Gula, the Unsated",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_gluttony.png",
    portrait = "assets/portraits/general_gluttony.png", -- large VN portrait for conversations (falls back if missing)
    archetype = "aggressive",
    stats = {
        health = 240, mana = 20, stamina = 18,
        staminaRegen = 3,
        damage = 20, magicDamage = 0, -- a beast: she hits in flesh, and every hit feeds her
        defense = 15, magicDefense = 8, -- warded in hide, thin against the magic she never learned
        movement = 4,
        speed = 4,
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Her rule rides on the Maw of the
    -- Unfed in the center (unstealable). Around it: the gralloch knife she eats with, and the pack she
    -- calls to the deep wood.
    startingItems = {
        "ability_summon_wolf", "ability_summon_wolf",     false,
        "weapon_gralloch_knife", "utility_maw_of_the_unfed", false,
        false,                 false,                      false,
    },
    defaultAction = "weapon_gralloch_knife",
    ai = {
        { priority = "high", act = "attack", item = "weapon_gralloch_knife",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
