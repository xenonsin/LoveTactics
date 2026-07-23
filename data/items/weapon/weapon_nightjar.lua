-- A dagger, so it is quick and it bleeds (docs/weapons.md). Its extra is what a KILL buys: cut something
-- down with it and the rogue is Unseen (status_invisible) until its next turn -- untargetable by anything
-- on the enemy's side.
--
-- Quest-only: `class` with no `price`.
--
-- The assassin's chain, and the answer to the rogue's actual problem, which has never been damage. A rogue
-- kills the thing it walked up to and is then standing in the middle of the enemy line with a knife, and
-- everything on the board takes a turn about it. This makes the kill itself the escape: finish somebody
-- and simply stop being a target for the beat it takes to walk out -- or to reach the next one.
--
-- It compounds with the family rather than with itself: a dagger is the fastest weapon in the game
-- (speed 2), so a Nightjar rogue that kills gets its own next turn very quickly AND arrives at it
-- unseen. The chain is kill, vanish, cross the field, kill.
--
-- Deliberately gated on the kill rather than on the hit. On a hit it would be a stealth button with a
-- knife attached; on a kill it is a reward for correct target selection, which is the skill the whole
-- rogue shelf is priced around -- and it does nothing at all on the turn the rogue picks wrong.
return {
    name = "Nightjar",
    description = "A quick, bleeding cut. Kill with it and you cannot be seen or targeted until your next turn.",
    flavor = "The bird is named for the noise it makes, which is nothing, and for when it makes it.",
    sprite = "assets/items/nightjar.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        -- A shade under an iron dagger's: what it sells happens after the target is already down, so it
        -- must not also be the best knife at putting them there.
        damage = { 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            fx.applyStatus(t, "status_bleed")
            -- Read AFTER the blow: `alive` is what Combat.dealFlatDamage has just finished deciding, so
            -- this is the kill check and needs no tally of its own.
            if not t.alive then
                fx.applyStatus(fx.user, "status_invisible")
                fx.log("action", string.format("%s is not there any more.",
                    (fx.user.char and fx.user.char.name) or "Unit"))
            end
        end,
    },
}
