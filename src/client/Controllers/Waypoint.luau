--!strict
-- A tall local light beam + distance label at the current target:
--   during a job -> the objective target; otherwise -> the tutorial step / next-goal location.
-- Purely visual and client-local (never replicated, never trusted).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Layout = require(ReplicatedStorage.Shared.Config.WorldLayout)

local Waypoint = {}

local beam: Part
local ring: Part
local label: TextLabel
local billboard: BillboardGui
local target: Layout.Point? = nil
local targetName = ""

local function makeParts()
	local folder = Instance.new("Folder")
	folder.Name = "LocalWaypoint"
	beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.45
	beam.Size = Vector3.new(6, 400, 6)
	beam.Parent = folder
	ring = beam:Clone()
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 40, 40)
	ring.Transparency = 0.6
	ring.Parent = folder

	billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(200, 44)
	billboard.LightInfluence = 0
	billboard.StudsOffsetWorldSpace = Vector3.new(0, -170, 0)
	billboard.Parent = beam
	label = Theme.label({ Parent = billboard, Size = UDim2.fromScale(1, 1), TextSize = 18, TextStrokeTransparency = 0.2 })
	folder.Parent = workspace
end

local function setTarget(pt: Layout.Point?, name: string, color: Color3)
	target = pt
	targetName = name
	beam.Color = color
	ring.Color = color
	local visible = pt ~= nil
	beam.Transparency = if visible then 0.45 else 1
	ring.Transparency = if visible then 0.6 else 1
	billboard.Enabled = visible
	if pt then
		beam.CFrame = CFrame.new(pt.x, 200, pt.z)
		ring.CFrame = CFrame.new(pt.x, 0.5, pt.z) * CFrame.Angles(0, 0, math.rad(90))
	end
end

local PLACE_LABELS: { [string]: string } = {
	JobBoard = "Job Board",
	NoodleStand = "Noodle Stand",
	CarLot = "Car Lot",
	RaceStart = "Race start",
}

local function refresh()
	local job = Store.job
	if job and job.objective and job.objective.target then
		setTarget(job.objective.target, job.name, Theme.colors.pink)
		return
	end
	local s = Store.state
	if not s then
		setTarget(nil, "", Theme.colors.rep)
		return
	end
	local placeId = if s.tutorial then s.tutorial.target else s.goal.target
	local pt = placeId and Layout.Places[placeId]
	setTarget(pt, PLACE_LABELS[placeId or ""] or "", Theme.colors.rep)
end

function Waypoint.start()
	makeParts()
	Store.on("state", refresh)
	Store.on("job", refresh)
	refresh()
	RunService.RenderStepped:Connect(function()
		if not target then
			return
		end
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = Layout.distance({ x = root.Position.X, z = root.Position.Z }, target)
			label.Text = string.format("%s\n%dm", targetName, math.floor(d * 0.28))
			-- keep the label near eye level when close, high up when far
			billboard.StudsOffsetWorldSpace = Vector3.new(0, if d < 120 then -185 else -150, 0)
		end
	end)
end

return Waypoint
