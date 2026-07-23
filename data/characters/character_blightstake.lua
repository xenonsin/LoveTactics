-- A Blightstake: a barbed stake dressed in rotted cloth, hammered into the ground where it will be in
-- the way. It cannot move and cannot be reasoned with, and every so often it spits something foul at
-- whatever is nearest.
--
-- Unlike the banner and the vigil, this one DOES take turns -- it is `control = "none"` (the AI drives
-- it) but it rides the initiative timeline like any other combatant, because the whole point of it is
-- that it acts. Slowly: its speed is deliberately poor, so a stake is worth roughly one attack for
-- every two a real archer would take.
--
-- WHAT IT IS FOR. Every summon in this catalog is a body that FIGHTS -- a wolf, an elemental, a
-- zombie -- and all of them are answers to "I want another attacker". This is the answer to a
-- different question: "I want that corridor to cost something to walk down, for the rest of the
-- battle, without me standing in it." Three stakes are not three fighters; they are a shape on the
-- board. The hunter's shelf is setup and then payoff (docs/classes.md), and this is setup that
-- keeps paying.
--
-- Its bite is poison rather than damage, on purpose: a stake that dealt real numbers would simply be a
-- cheap archer. Poison is a clock, and a clock the enemy has to walk past four of is a genuinely
-- different threat from one that has to be shot four times.
return {
    name = "Blightstake",
    sprite = "assets/chars/blightstake.png",
    -- `guard` rather than `skirmish`: a stake with no movement must not be given a posture whose whole
    -- plan is repositioning, or the AI spends every turn trying to walk somewhere it cannot go.
    archetype = "guard",
    stats = {
        health = 14, mana = 0, stamina = 20,
        damage = 4, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 0, -- hammered in: it holds exactly the tile it was set on
        speed = 9,    -- slow: roughly one spit for every two shots a real archer takes
    },
    startingItems = { "weapon_blight_spitter" },
    ai = {
        -- The stake has no legs and no judgement; it spits at whatever is closest. Stated rather than
        -- left to the posture's floor so its one behaviour is visible in the tactics editor, which is
        -- the rule every combatant blueprint in this catalog follows.
        { act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
