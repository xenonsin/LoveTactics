-- COMMON. Luck raises Avoid and blunts an attacker's crit (docs/accuracy.md) -- the defensive half of the
-- accuracy pair, opposite The Long Lesson. Authored as its own relic rather than folded in with skill
-- because the two answer different fears, and a player who keeps getting critted should be able to buy
-- the answer to that specifically.
return {
    name = "The Thumbed Die",
    blurb = "+%d luck for the whole company -- blows miss, and land softer.",
    tier = "common", mark = "Di",
    scale = { 1, 1 },
    bonus = { luck = 1 },
}
