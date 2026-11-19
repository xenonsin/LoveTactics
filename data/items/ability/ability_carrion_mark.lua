-- Carrion Mark: the hunter's Reaper planner (docs/engines.md). Mark a foe; if it falls while the mark
-- holds, by anybody's hand, the hunter's next action comes round 2 sooner (status_quickened, granted by
-- Engine.onFell). It deals nothing, and it is quick enough to be a Tempo action for a fighter-hunter.
-- What it rewards is choosing the kill order before the kills.
return {
    name = "Carrion Mark",
    description = "Marks a foe. If it falls within 2 turns, your next action costs 2 less time.",
    flavor = "The crows find it first. The hunter only has to follow them.",
    sprite = "assets/items/ability_carrion_mark.png",
    type = "ability",
    tags = { "physical" },
    class = "hunter",
    price = 180,
    unlockLevel = 7,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        speed = 2,
        cost = { stat = "stamina", amount = 4 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_carrion_mark")
        end,
    },
}
