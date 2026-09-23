-- TORN SHOULDER: the arm does not come all the way back.
--
-- Three points off Damage, itemised in the breakdown under its own name. This is the cut the count-based
-- meter used to apply at two wounds and three, pulled out of the ladder and made into a thing that
-- happened to a shoulder -- so it arrives on the roll rather than on the count, and the body that has it
-- is the body that has it rather than "anyone carried out twice".
--
-- IT PUNISHES THE BODY YOU MOST WANT TO FIELD, which is the decision the whole meter exists for. A
-- veteran three points down still out-hits a fresh recruit for a long while; the question of when that
-- stops being true is the question, and it is only interesting if the number is small enough to argue
-- about. Two was too quiet to read in a breakdown and four took the argument away.
return {
    name = "Torn Shoulder",
    description = "Torn Shoulder: strikes for less.",
    severity = 2,
    weight = 15,
    reserve = { health = 0.06 },
    effects = { { id = "status_torn_shoulder" } },
}
