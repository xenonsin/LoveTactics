-- THE DEAD HAND: what the hand takes, it keeps. Each dark blow that reaches a body takes 5 mana out of it
-- into the striker's pool (Combat.dealFlatDamage, after the wound is final -- a warded blow draws nothing).
return {
    name = "The Dead Hand",
    description = "Your dark hits take 5 mana from the target into your own pool.",
    manaThief = 5,
}
