-- Quest blueprint. `requiredPrestige` gates when the quest appears on the
-- board; `Quest.available(prestige)` filters on it.
return {
    name = "Bandit Ambush",
    description = "Raiders have blocked the north road. Clear them out.",
    difficulty = "Easy",
    rewardGold = 50,
    requiredPrestige = 1,
}
