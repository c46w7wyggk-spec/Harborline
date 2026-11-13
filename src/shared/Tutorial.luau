--!strict
-- Onboarding steps (shared so the client can render them; the server decides when they advance).

local Tutorial = {}

Tutorial.STEPS = {
	{ id = "board", text = "Welcome to Harborline! Walk to the glowing JOB BOARD in the plaza.", target = "JobBoard" },
	{ id = "start", text = "Open the Job Board (or the Phone button) and start a Courier Run.", target = "JobBoard" },
	{ id = "deliver", text = "Follow the light beam: grab parcels at the Depot, then deliver all 3.", target = nil },
	{ id = "buy", text = "Nice pay! Spend $500 on the Noodle Cart - it earns cash while you play.", target = "NoodleStand" },
	{ id = "drive", text = "Spawn a car (Phone > Garage) and race the Harbor Sprint.", target = "RaceStart" },
}
Tutorial.COUNT = #Tutorial.STEPS
Tutorial.DONE = Tutorial.COUNT + 1

function Tutorial.step(index: number)
	return Tutorial.STEPS[index]
end

function Tutorial.indexOf(id: string): number
	for i, s in Tutorial.STEPS do
		if s.id == id then
			return i
		end
	end
	return Tutorial.DONE
end

return Tutorial
