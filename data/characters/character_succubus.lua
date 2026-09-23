-- A SUCCUBUS: the middle rung of this line, and the body that puts the Lust circle's FIRST VERB on a
-- board a company can meet more than once.
--
-- `Descent.SINS` lists five verbs for this stratum and CHARM heads the list -- "you do not choose whose
-- side you are on". Until this line arrived nothing ROLLABLE on the castle delivered it: the one body
-- that charmed was the Suppliant, and she was seated -- one landing, once, at the end of the circle. So
-- the circle's headline rule and the counterplay its own header argues at length -- cut the charmer and
-- everyone she holds comes home, mid-turn (Combat.releaseCharmedBy) -- existed in prose and in no fight a
-- player could learn from. This is where that is learned.
--
-- ...AND IT IS NOW THE ONLY PLACE. The Suppliant was deleted with the other six lieutenants on
-- 2026-09-22, so this line is the whole of Lust's charm rather than the rollable half of it.
--
-- THE ESCALATION IS EXACTLY ONE SENTENCE, which is what this whole line is built as:
--
--   the lesser    the kiss, the cast, and one of the church's own standing with her.
--   the succubus  the same, and she DRINKS off what her congregation does (trait_borrowed_blood).
--   the Abbess    the same, and she HIDES behind it (trait_the_congregation), and takes one of yours
--                 at the bell as well.
--
-- SO A PLAYER MEETS THE CHARM HERE, AT ONE BODY'S VOLUME, with the counterplay legible because there
-- is only one thing on the board it could be: kill her and your own walks back. That is the lesson the
-- Lady Chapel then charges for, where cutting her is the thing her own congregation is standing in the
-- way of (data/traits/trait_the_congregation.lua).
--
-- THE ROLL IS THE SOFTENING CURVE (Status.charmChance): 25% against a whole body, climbing to 85%
-- against one nearly down. Which makes her a REAR-GUARD threat rather than an opener -- she is almost
-- harmless to a fresh company and takes the best body on the field off a company that has been walked
-- through a floor of harpies and coils first. The counterplay is a health bar, not a dice read.
--
-- AND SHE KEEPS THE KISS, deliberately, rather than trading it for the cast. A charmer that could only
-- charm would be a body the party ignores between rolls; the kiss means closing on her to stop the
-- rolls is itself the thing she wants. The two moves are one decision pointed at the company: come and
-- be moved, or stand off and be taken.
--
-- WHAT SHE IS, IN THE FICTION. The Cathedral's rite taken cleanly -- see the lesser one's header for
-- the whole of it, and for why holy bites this line half as hard as it bites the rest of the keep.
-- Nothing went wrong with her. That is the horror of her.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). Low in it, beside the harpy: the line bodies of
-- this circle are thin on purpose, because what kills a company here is the keep and not the body.
return {
    name = "Succubus",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/succubus.png",
    stats = {
        health = 46, mana = 30, stamina = 18,
        staminaRegen = 2,
        damage = 11, magicDamage = 13, -- the cast is the threat; the kiss is what stops you answering it
        defense = 5, magicDefense = 10,
        movement = 5,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 8,
    },
    -- The same nothing the lesser ones wear, worn with more conviction -- and conviction has never
    -- once stopped a mace. See character_lesser_succubus for why this line carries no physical entry
    -- at all and why holy bites it half as hard as it bites the rest of the keep.
    resist = { dark = 3, holy = -3 }, -- tier 2: Balance.INNATE_BUDGET is 3
    startingItems = { "weapon_parting_kiss", "weapon_the_anointing",
                      "utility_the_blooded", "utility_borrowed_blood" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), and it is the TAKING first. ability_charm used to sit on
    -- the thief shelf at 610 gold, which said that turning a body is a technique a fence teaches for
    -- money; it is `unstocked` now -- no counter deals one in either direction -- and this line is the
    -- only place in the game it comes from. Second is her own trade, so a company that already holds
    -- the charm is paid the kiss rather than nothing (Descent.dropFor walks the list in order and
    -- skips what you hold), which is also why the list reads rarest first.
    drops = {
        "ability_charm",
        "utility_the_offered_place",
    },
    -- The kiss rather than the cast: `defaultAction` is what a compulsion and a counter swing
    -- (models/ai.lua), and what this body does to something already standing next to it is move it.
    -- The planner reaches for the Anointing on its own whenever the kiss cannot.
    defaultAction = "weapon_parting_kiss",
    -- `skirmish` where the lesser one closes, and the pair is the escalation stated in posture: a body
    -- whose only move is reach 1 has to come to you, and a body with a cast at three wants the gap it
    -- casts across. She is the first thing on this line a company has to go and GET.
    archetype = "skirmish",
    ai = {
        -- SHE REACHES FOR WHOEVER IS ALREADY GIVING WAY, which is the charm's own curve read as a
        -- target preference: the roll pays 25% against a whole body and 85% against one nearly down,
        -- so a charmer that picked the nearest foe would be spending most of its mana on refusals.
        -- (`lowest_hp` and not some reading of distance: AI.TARGET_PREF_ORDER is the whole list of
        -- preferences the planner implements, and a field it does not know scores zero in silence.)
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
