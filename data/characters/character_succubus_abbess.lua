-- A SUCCUBUS ABBESS: the top of the Lust circle's third line, and the one body on the stratum whose
-- whole fight is about WHOSE a body is rather than where it is standing.
--
-- THE ESCALATION IS IN KIND, NOT IN SIZE, which is what separates an alpha from a bigger piece of
-- chaff -- and here it is in kind twice over:
--
--   the lesser    the kiss, the cast, and one of the church's own standing with her.
--   the succubus  the same, and she drinks off what her congregation does (trait_borrowed_blood).
--   the Abbess    the same, plus what a charmed body is FOR. She also takes one of YOURS at the bell
--                 (trait_the_first_yes), so the biggest thing the company built is standing beside her
--                 thralls; and every wound meant for her opens in all of them at once
--                 (trait_the_congregation). She does not touch the floor either (utility_fallen_wings).
--
-- SO THE FIGHT IS A CLOSED ROOM WITH TWO DOORS IN IT, and both doors are the stratum's own law. Swing
-- at her and the blow lands on your anvil, whole. Leave her alone and she drinks off what your anvil is
-- doing to your line. What is left is the pair Descent.SINS already wrote down as this circle's
-- counterplay -- **cut the one doing it, or cure your own** -- and this is the body that finally makes
-- both of them cost something. Cure or Panacea frees the victim and takes a place off the split; the
-- charm runs out on its own ten ticks; and the moment she falls, everyone she held comes home
-- mid-turn (Combat.releaseCharmedBy).
--
-- WHICH IS WHY SHE IS AN ELITE AND NOT A BOSS. `boss = true` means an assassinate mark and nothing else
-- (docs/bestiary.md); she is the discipline stated, not a quest's conclusion. So she is Charmable,
-- Polymorphable and open to a finisher -- and being takeable is the right answer for the body on this
-- floor that spends its fight taking, exactly as it was for the Matriarch and the Elder.
--
-- SHE IS THIN, AND THAT IS THE BUDGET RATHER THAN AN OVERSIGHT. Lowest health of the stratum's three
-- elites -- under the Elder's 104 and the Matriarch's 112 -- because a body that redirects the whole
-- blow does not also need the bar to eat it. What she is paying for is the redirect: strip the charm
-- and she is a fast caster with a knife.
--
-- ...AND SUNDER TAKES ALL OF IT AT ONCE. Trait.flag refuses every flagged rule on a body holding
-- `status_sundered`, and the split and the opening ride one vessel (utility_the_anointed), so silencing
-- her relic is hitting her directly for as long as it holds. That is a real and deliberate second key
-- to this fight, sitting on a shelf most companies already own.
--
-- WHAT SHE IS, IN THE FICTION. The rite taken cleanly and then put in charge of a house. See the lesser
-- one's header for the blooding and for why holy bites this line half as hard as it bites the rest of
-- the keep -- the blood in her is the Cathedral's own, which is also why she is the body in this circle
-- that reads as an argument with Luxuria rather than a servant of her (data/characters/character_general_lust.lua).
--
-- Tier 3's band is 81-154 health (Balance.HEALTH_BANDS).
return {
    name = "Succubus Abbess",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/succubus_abbess.png",
    stats = {
        health = 92, mana = 50, stamina = 22,
        staminaRegen = 3,
        damage = 12, magicDamage = 16,
        defense = 7, magicDefense = 13,
        movement = 4, -- she does not need the ground: see utility_fallen_wings
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 9, luck = 9,
    },
    -- FOOTPRINT 1x1, like the Matriarch and the Elder and for the same reason: the Thinwall Keep is a
    -- warren of doorways and a two-by-two body cannot use one.
    --
    -- She has never needed anything between herself and a blow, and so she has nothing. What she has
    -- instead is somebody else, and it is on the other page (data/traits/trait_the_congregation.lua).
    -- See character_lesser_succubus for why this line carries no physical entry at all.
    resist = { dark = 4, holy = -4 }, -- tier 3: Balance.INNATE_BUDGET is 4
    startingItems = { "weapon_parting_kiss", "weapon_the_anointing", "utility_the_blooded",
                      "utility_the_anointed", "utility_borrowed_blood", "utility_fallen_wings" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), and it is the whole pair. The taking first -- ability_charm
    -- is `unstocked`, off every counter in both directions, and this line is the only place in the game
    -- it comes from -- then the PAYOFF, which is the half nothing else in the game does at all: a turned
    -- body that is also a wall. A company that walks out of the Lady Chapel with both has been taught a
    -- rule in two halves by the body that used both halves on it, and one that walks out with one has a
    -- reason to go back down.
    --
    -- Rarest first, because Descent.dropFor walks the list in order and skips what you hold -- so a
    -- company that already carries the charm is paid the Congregation, and one that carries both is
    -- paid the kiss rather than nothing.
    drops = {
        "ability_charm",
        "utility_the_congregation",
        "utility_the_offered_place",
    },
    defaultAction = "weapon_parting_kiss",
    archetype = "skirmish",
    ai = {
        -- THE CHARM'S OWN CURVE, READ AS A TARGET PREFERENCE. Status.charmChance pays 25% against a
        -- whole body and 85% against one nearly down, so a charmer that reached for the nearest foe
        -- would spend most of its mana on refusals. The opening is the exception and it is the trait's,
        -- not the planner's: The First Yes takes the BIGGEST body on the field, free and unrolled,
        -- because the fight has to open with somebody already hers.
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
