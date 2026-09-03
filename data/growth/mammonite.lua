-- Per-level stat gains for a character growing as a mammonite (rogue discipline).
-- The purse: a body worth keeping alive, because its damage is BOUGHT rather than swung.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on mammonite stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- The lowest damage growth of the three rogue paths (assassin 5, thief 2), and deliberately so: a
    -- mammonite's output is priced in coin, not in Power. The Gilded Wound folds none of its bearer's
    -- damage stat in at all, and Blood Money's floor is a modest jab -- so a point of damage a level
    -- buys this build almost nothing, while a point of health buys it another blow it can afford to
    -- stand there and pay for. The pool is where the budget goes.
    --
    -- Health 5 is the top of the rogue paths (assassin 3, thief 3) and reads as the archetype rather
    -- than as generosity: the whole point of an open account is being the unit that takes the hit and
    -- bills it, and a body that falls before the purse empties has wasted the gold it already spent.
    -- Speed 1 (the base rogue's, not the assassin's 2) because tempo is the one thing this shelf can
    -- simply BUY -- Grease Palms hastes for coin, so growing into speed would be paying twice.
    speed = 1, damage = 1, stamina = 4, health = 5,
}
