-- A LESSER SUCCUBUS: the first rung of the Lust circle's THIRD animal, and the cheapest possible
-- statement of the one verb this line owns.
--
-- IT IS THE WHOLE LINE AT ITS SMALLEST, AND THAT IS WHAT IT IS FOR. Every succubus does the same two
-- things -- the kiss trades tiles with whatever it strikes, the Anointing takes whose side a body is
-- on -- and every one of them walks onto the board already holding somebody. This one holds ONE, casts
-- twice before it is dry, and dies to a couple of blows. A player who meets it in the Long Gallery
-- learns the entire fight for the price of some chaff: she has a person standing with her, that person
-- is hers rather than a demon, and when she goes down he comes back to himself and walks out.
--
-- WHICH IS THE LADDER. Three bodies carry this line and each is the one below plus one sentence: this
-- one shows the rules, the Succubus drinks off what her congregation does (trait_borrowed_blood), and
-- the Abbess hides behind it outright (trait_the_congregation). By the time the Lady Chapel opens there
-- is nothing on that board a company has not already been shown somewhere cheaper.
--
-- AND IT IS A DIFFERENT KIND OF DISPLACEMENT FROM THE OTHER TWO ANIMALS, which is the reason the circle
-- can field a third at all. The talons haul a body IN, the gust drives one OUT -- the flock moves you
-- and stays put. This one moves you by MOVING ITSELF: it takes your tile and gives you its own, so the
-- board after the exchange has the same shape with two names swapped. In the Thinwall Keep that is a
-- body standing on the far side of the door its line was holding, alone, with the room's other
-- occupants for company.
--
-- SO IT PUNISHES CLOSING, WHICH NOTHING ELSE ON THIS GROUND DOES. A harpy wants the gap; a lamia wants
-- you held beside it; this one wants you to come to it. Between the three, every distance a company
-- can choose is somebody's preferred distance, and that is what makes the stratum a place rather than
-- a difficulty.
--
-- WHAT IT IS, IN THE FICTION. The same rite as the rest of the keep, taken a third way. The harpies and
-- the lamiae are bloodings that went WRONG -- children the Cathedral's rite half-took and then hunted
-- (docs/story.md, "The blooding"). This line is what the rite produces when it takes CLEANLY, and the
-- lesser ones are the early work: they came out wearing a face, which is more than the flock managed,
-- and not much else.
--
-- WHICH IS WHY HOLY BITES IT LESS. Every body on this stratum carries a negative holy line -- every
-- demon in the game must (docs/bestiary.md, "A demon takes holy the harder") -- but this line carries
-- HALF the flock's, because the blood in it is the Cathedral's own and burning it is closer to burning
-- the altar than to burning something that crawled in from the wild. A Smite is the right answer to
-- everything else on the floor and a merely adequate one here.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). High in it: it has to survive being reached,
-- because being reached is when it does its one thing.
return {
    name = "Lesser Succubus",
    race = "demon",
    tier = 1,
    sprite = "assets/chars/lesser_succubus.png",
    stats = {
        health = 28, mana = 20, stamina = 16, -- two asks and she is dry: the cast costs 10
        staminaRegen = 3,
        damage = 10, magicDamage = 9,
        defense = 4, magicDefense = 6,
        movement = 5,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 8,
    },
    -- SHE HAS NO HIDE, AND THE EMPTY PHYSICAL LINE IS THE STATEMENT RATHER THAN AN OMISSION.
    -- Balance.INNATE_PHYSICAL makes a creature's slash/pierce/impact lines a REDISTRIBUTION -- they must
    -- sum to zero, so turning a blade aside costs the body a mace. Every other animal on this stratum
    -- has something to trade: feathers lie flat over each other (the flock), scale slides an edge down
    -- its own lie (the coils). This line wears a face and nothing else. There is no redistribution here
    -- because there is nothing to redistribute, and a blow that reaches her lands on skin.
    --
    -- WHICH IS WHY HOLY BITES IT HALF AS HARD AS IT BITES THE REST OF THE KEEP. Every demon must go
    -- into a fight with a negative holy line (docs/bestiary.md, "A demon takes holy the harder") and
    -- this one does -- but at the budget rather than at twice it, where the harpies and the lamiae sit.
    -- The harpies and the lamiae are bloodings that took WRONG. This line is what the rite makes when
    -- it takes cleanly, so the blood a Smite is asked to burn is the Cathedral's own.
    resist = { dark = 2, holy = -2 }, -- tier 1: Balance.INNATE_BUDGET is 2
    startingItems = { "weapon_parting_kiss", "weapon_the_anointing", "utility_the_blooded" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). The trade, handed over: the bearer's melee blows change
    -- tiles with what they hit. The rift sells you the trick, which is the ordering the Barrow Lord
    -- argues -- a rule like that is strange handed cold at a counter and ordinary handed by the corpse
    -- of the thing that spent a fight doing it to you.
    drops = {
        "ability_charm",
        "utility_the_offered_place",
    },
    defaultAction = "weapon_parting_kiss",
    -- `aggressive`: the kiss is its best move and the kiss is reach 1, so a body that held the gap
    -- would spend the fight walking. It closes because closing IS the threat -- the trade only happens
    -- where the company is -- and the two casts it can afford are what it does on the way in.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
