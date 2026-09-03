-- THE ROLL: where the company is written down, and where you say what each body is.
--
-- The one screen the class system needs and did not have. A body carries a declared job that decides
-- how it grows (models/growth.lua's Growth.jobOf) and a level in every class it has ever swung
-- (Discipline.classLevel) -- both written every fight, both persisted through every save, and until
-- this door existed both shown to nobody.
--
-- ON THE PLAZA'S EMPTY SLOT, which was left open for exactly this. models/building.lua's GRID note
-- says the space under the Gate is "the approach -- the avenue the plaza opens onto -- and it is also
-- the next card's home, so the city can grow once more without the layout moving." This is that card.
--
-- NO UNLOCK GATE. Every other door in the city arrives on the deed that gives it a job -- a wound for
-- the Inn, four floors for the Forge -- and this one has a job from the first morning: the starting
-- company already has jobs to declare and a ladder to read. A screen that explains what your bodies
-- are cannot be the reward for having already worked it out.
return {
    name = "The Roll",
    order = 9,
    x = 490,
    y = 480,
    w = 300,
    h = 130,
    panel = "jobs",
    description = "Every hand you have, and what each of them is becoming.",
}
