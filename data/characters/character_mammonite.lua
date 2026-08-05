-- Mammonite exemplar (rogue subclass). The purse: gold is a combat resource in both directions -- coin
-- buys damage, tempo and your own skin, and every blow banks more of it. Met at Quarter-End
-- (data/quests/undercroft/quest_undercroft_slot_06.lua) as a rival contractor working the same list, a
-- recruit. Kit from data/disciplines/mammonite.lua.
--
-- WHO IT IS. Not a robber and not a killer -- a contractor. The Bank closes its books on quarter-end
-- night, hires out the overflow at a posted rate, and this is the professional who has been doing that
-- work for years and is very good at it. Nothing it does to you is illegal. It is carrying the firm's
-- float, its paperwork is impeccable, and it will bill your estate for the recovery.
--
-- THE BODY IS THE STATEMENT. Damage 12 -- the lowest of the three rogue exemplars (assassin 21, thief
-- 15) -- and health 105, the highest by a wide margin. That is the growth table (data/growth/mammonite.lua)
-- said in one glance: a mammonite's output is BOUGHT, not swung, so a point of Power buys it almost
-- nothing and a point of health buys it another blow it can stand there and pay for. The iron dagger is
-- the same sentence: it does not fight with the knife, and the knife is exactly as good as that implies.
--
-- THE COFFER IS WHAT MAKES THE KIT RUN AT ALL. Every purse ability is inert without money to spend, and
-- an enemy spends its own `coffer` rather than the player's bank (Combat.purseAvailable is side-aware).
-- 300 is a working float, not a hoard: three or four bought blows, or a long-ish account, and then it is
-- a mediocre knife-fighter -- which is the fight this unit is designed to lose. Compare Aurea's 600
-- (data/characters/character_general_greed.lua), sized to be an economy rather than a purse.
--
-- AND IT INVERTS ON RECRUITMENT, which is the detail worth keeping. The same body on the party's side
-- reads `combat.purse` instead -- your campaign gold, the real bank. Nothing about the blueprint changes;
-- whose money it is does. A hired collector that turns and spends YOUR money on YOUR behalf is the entire
-- joke of the discipline, and it costs no code to tell.
--
-- INCOME IS PASSIVE, SPENDING IS DELIBERATE, and the split is why there are only three AI rules for an
-- eight-item shelf. The Cutpurse's Coat banks coin off every blow it lands (trait_skimmers_cut) with no
-- decision attached, so the rules never have to think about earning -- they only ever decide what to buy.
-- A Price on the Head rides in the grid without a rule of its own; the generic scorer reaches for it, and
-- a player who recruits this body gets the income half of the shelf along with the spending half.
--
-- The coat rather than utility_skimmers_cut, which carries the identical trait: two of them is one of
-- them, and the coat pays a defense bonus on top of the skim.
return {
    name = "Mammonite",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/mammonite.png",
    class = "rogue",
    discipline = "mammonite",
    -- `holdGround`: a hoard does not chase. It plants itself, prices whatever walks into range 3, and
    -- lets the account soak what reaches it -- a posture the kit actively wants, since The Open Account
    -- only pays for wounds it is standing there to take.
    archetype = "holdGround",
    stats = {
        health = 105, mana = 10, stamina = 26,
        staminaRegen = 2,
        damage = 12, magicDamage = 4, -- it does not duel; it prices you
        defense = 10, magicDefense = 8,
        movement = 4,
        speed = 4,
    },
    -- The firm's float, spent by everything in the middle column (Combat.spendPurse reads an enemy's
    -- coffer). Ignored entirely once this body is on the party's side -- see the header.
    coffer = 300,
    -- The 3x3 grid, row-major. The whole spending half of the shelf across the top and middle, the
    -- income half in the coat, and a knife it would rather not use in the corner.
    startingItems = {
        "ability_gilded_wound", "ability_open_account",      "ability_blood_money",
        "ability_grease_palms", "armor_cutpurse_coat",       "ability_price_on_the_head",
        "weapon_iron_dagger",   "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_dagger",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    --
    -- The Open Account is the signature rather than Blood Money (the shelf's flagship) because it is the
    -- one that cannot be mistaken for anything else on the board: a unit paying its wounds in gold is the
    -- discipline, stated. Blood Money read alone is just a strike that hits a bit harder.
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "ability_open_account",
    ai = {
        -- OPEN THE BOOKS FIRST, and exactly once. A toggle cast unconditionally would flip the account
        -- shut again on the following turn and keep flipping it forever, so the rule is gated on the
        -- status being absent -- which is also what makes it fire on turn one, before anybody has swung.
        { priority = "urgent", act = "cast", item = "ability_open_account",
          when = { subject = "self", test = "lacks_status", value = "status_open_account" } },
        -- Then price whatever is reachable, Aurea's own shape: The Gilded Wound reaches three tiles, so a
        -- foe it cannot touch with the dagger it can still bill. The scorer pours what the coffer can
        -- afford (models/ai.lua prices the blow it intends to buy), so a rich contractor hits harder and a
        -- broke one scores zero here and falls through.
        { priority = "high", act = "attack", item = "ability_gilded_wound",
          when = { subject = "any_foe", test = "in_reach" } },
        -- Broke, or with something already in its face: the modest swing with whatever coin is left
        -- poured into it. Blood Money still lands its floor on an empty float, so this rule never dies.
        { priority = "normal", act = "attack", item = "ability_blood_money",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
    },
}
