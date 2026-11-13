--!strict
-- Always-on HUD: money/Rep, active objective + timer, next goal / tutorial card, toasts,
-- job result card, and the Phone button that opens the menus.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local new = Theme.new
local colors = Theme.colors

local HUD = {}
local gui: ScreenGui
local refs: { [string]: any } = {}
local openMenuCallback: ((string) -> ())? = nil

function HUD.onPhone(cb: (string) -> ())
	openMenuCallback = cb
end

local function panel(props: { [string]: any }): Frame
	local base = { BackgroundColor3 = colors.panel, BackgroundTransparency = 0.12, BorderSizePixel = 0 }
	for k, v in props do
		base[k] = v
	end
	local f = new("Frame", base)
	Theme.corner(14).Parent = f
	return f
end

local function bar(parent: Instance, color: Color3, position: UDim2, size: UDim2): Frame
	local back = new("Frame", { Parent = parent, BackgroundColor3 = colors.panelLight, BorderSizePixel = 0, Position = position, Size = size })
	Theme.corner(6).Parent = back
	local fill = new("Frame", { Parent = back, Name = "Fill", BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) })
	Theme.corner(6).Parent = fill
	return back
end

local function setBar(back: Frame, fraction: number)
	local fill = back:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

---------------------------------------------------------------------------- build

local function build()
	local player = Players.LocalPlayer
	gui = new("ScreenGui", {
		Name = "HarborlineHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = new("UIScale", { Parent = gui })
	local function rescale()
		local vp = Workspace.CurrentCamera.ViewportSize
		-- never shrink below 1 on touch so buttons stay >= 48 px
		local s = math.clamp(vp.Y / 720, if Theme.isTouch() then 1 else 0.8, 1.3)
		scale.Scale = s
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- stats (top-left)
	local stats = panel({ Parent = gui, Name = "Stats", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(230, 74) })
	Theme.padding(8).Parent = stats
	refs.cash = Theme.label({ Parent = stats, Text = "$0", TextSize = 28, TextColor3 = colors.cash, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30) })
	refs.level = Theme.label({ Parent = stats, Text = "Rep Lv 1", TextSize = 16, TextColor3 = colors.rep, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 16) })
	refs.repBar = bar(stats, colors.rep, UDim2.fromOffset(0, 50), UDim2.new(1, 0, 0, 8))

	-- objective (top-centre, only during a job)
	local obj = panel({ Parent = gui, Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(420, 96), Visible = false })
	Theme.padding(8).Parent = obj
	refs.objective = obj
	refs.jobName = Theme.label({ Parent = obj, Text = "", TextSize = 16, TextColor3 = colors.accent, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 0, 18) })
	refs.objText = Theme.label({ Parent = obj, Text = "", Font = Theme.bodyFont, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, -110, 0, 44) })
	refs.timer = Theme.label({ Parent = obj, Text = "0:00", TextSize = 34, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 0), Size = UDim2.fromOffset(84, 40) })
	refs.objBar = bar(obj, colors.pink, UDim2.new(0, 0, 1, -10), UDim2.new(1, -52, 0, 8))
	refs.objBarLabel = Theme.label({ Parent = obj, Text = "", TextSize = 13, TextColor3 = colors.pink, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, -60, 0, 16) })
	local cancel = Theme.button({ Parent = obj, Text = "X", BackgroundColor3 = colors.bad, TextColor3 = colors.text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(Theme.MIN_TOUCH, Theme.MIN_TOUCH) })
	cancel.Activated:Connect(function()
		Store.request("CancelJob")
	end)

	-- goal / tutorial card (bottom-left; above the touch thumbstick area on phones)
	local goal = panel({ Parent = gui, Name = "Goal", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, if Theme.isTouch() then -190 else -16), Size = UDim2.fromOffset(300, 84) })
	Theme.padding(8).Parent = goal
	refs.goalTitle = Theme.label({ Parent = goal, Text = "NEXT GOAL", TextSize = 13, TextColor3 = colors.rep, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 14) })
	refs.goalText = Theme.label({ Parent = goal, Text = "Loading your save...", Font = Theme.bodyFont, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40) })
	refs.goalBar = bar(goal, colors.cash, UDim2.new(0, 0, 1, -8), UDim2.new(1, 0, 0, 6))
	refs.skip = Theme.button({ Parent = goal, Text = "Skip", TextSize = 14, BackgroundColor3 = colors.panelLight, TextColor3 = colors.muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4), Size = UDim2.fromOffset(56, 30), Visible = false })
	refs.skip.Activated:Connect(function()
		Store.request("SkipTutorial")
	end)

	-- phone button (top-right, clear of the touch jump button)
	local phone = Theme.button({ Parent = gui, Name = "Phone", Text = "PHONE", TextSize = 16, BackgroundColor3 = colors.pink, TextColor3 = colors.text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(96, 56) })
	phone.Activated:Connect(function()
		if openMenuCallback then
			openMenuCallback("phone")
		end
	end)
	refs.phoneHint = Theme.label({ Parent = phone, Text = if Theme.isTouch() then "" else "[J]", TextSize = 12, TextColor3 = colors.text, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 14) })

	-- toasts (centre, under the objective)
	refs.toasts = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(440, 160) })
	new("UIListLayout", { Parent = refs.toasts, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })

	-- Studio memory-mode banner
	refs.banner = Theme.label({ Parent = gui, Text = "STUDIO TEST MODE - progress not saved", TextSize = 13, TextColor3 = colors.warn, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(400, 16), Visible = false })

	-- speedometer (only while driving)
	refs.speed = Theme.label({ Parent = gui, Text = "", TextSize = 30, TextColor3 = colors.text, TextStrokeTransparency = 0.4, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(200, 34), Visible = false })

	-- result card
	local result = panel({ Parent = gui, Name = "Result", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(380, 220), Visible = false, ZIndex = 5 })
	Theme.padding(14).Parent = result
	refs.result = result
	refs.resTitle = Theme.label({ Parent = result, Text = "", TextSize = 30, Size = UDim2.new(1, 0, 0, 36), ZIndex = 5 })
	refs.resReason = Theme.label({ Parent = result, Text = "", Font = Theme.bodyFont, TextSize = 17, TextColor3 = colors.muted, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 44), ZIndex = 5 })
	refs.resReward = Theme.label({ Parent = result, Text = "", TextSize = 26, TextColor3 = colors.cash, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 34), ZIndex = 5 })
	local back = Theme.button({ Parent = result, Text = "Back to free roam", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.55, -4, 0, Theme.MIN_TOUCH), ZIndex = 5 })
	local again = Theme.button({ Parent = result, Text = "More jobs", BackgroundColor3 = colors.rep, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.45, -4, 0, Theme.MIN_TOUCH), ZIndex = 5 })
	back.Activated:Connect(function()
		result.Visible = false
	end)
	again.Activated:Connect(function()
		result.Visible = false
		if openMenuCallback then
			openMenuCallback("jobs")
		end
	end)
	refs.resBack = back
end

---------------------------------------------------------------------------- updates

local function renderState(s: any)
	if not s then
		return
	end
	refs.cash.Text = Theme.money(s.cash)
	if s.nextLevelRep then
		refs.level.Text = string.format("Rep Lv %d   %d / %d", s.level, s.rep, s.nextLevelRep)
		setBar(refs.repBar, (s.rep - s.levelRep) / (s.nextLevelRep - s.levelRep))
	else
		refs.level.Text = string.format("Rep Lv %d (max)   %d", s.level, s.rep)
		setBar(refs.repBar, 1)
	end
	if s.tutorial then
		refs.goalTitle.Text = string.format("TUTORIAL %d/%d", s.tutorial.step, s.tutorial.total)
		refs.goalText.Text = s.tutorial.text
		setBar(refs.goalBar, (s.tutorial.step - 1) / s.tutorial.total)
		refs.skip.Visible = true
	else
		refs.goalTitle.Text = "NEXT GOAL"
		refs.goalText.Text = s.goal.text
		setBar(refs.goalBar, s.goal.progress or 0)
		refs.skip.Visible = false
	end
	refs.banner.Visible = s.memoryMode == true
end

local function renderJob(msg: any)
	if not msg then
		refs.objective.Visible = false
		return
	end
	local o = msg.objective
	refs.objective.Visible = true
	refs.jobName.Text = string.upper(msg.name)
	refs.objText.Text = o.text
	refs.timer.Text = Theme.clock(o.timeLeft or 0)
	refs.timer.TextColor3 = if (o.timeLeft or 99) <= 15 then colors.bad else colors.text
	if o.heat then
		refs.objBarLabel.Text = "HEAT"
		setBar(refs.objBar, o.heat)
	elseif o.progress then
		refs.objBarLabel.Text = "CRACKING"
		setBar(refs.objBar, o.progress)
	elseif o.elapsed then
		refs.objBarLabel.Text = string.format("RACE TIME %.1fs", o.elapsed)
		setBar(refs.objBar, (o.checkpointIndex - 1) / #o.checkpoints)
	else
		refs.objBarLabel.Text = ""
		setBar(refs.objBar, 0)
	end
end

local function toast(n: any)
	local color = if n.kind == "success" then colors.good elseif n.kind == "warn" then colors.warn elseif n.kind == "job" then colors.accent else colors.text
	local t = panel({ Parent = refs.toasts, Size = UDim2.fromOffset(440, 38), BackgroundTransparency = 0.2 })
	Theme.label({ Parent = t, Text = n.text, Font = Theme.bodyFont, TextSize = 16, TextColor3 = color, Size = UDim2.fromScale(1, 1) })
	local items = refs.toasts:GetChildren()
	local frames = {}
	for _, c in items do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames > 3 then
		frames[1]:Destroy()
	end
	task.delay(4, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			t:Destroy()
		end
	end)
end

local function showResult(r: any)
	refs.result.Visible = true
	if r.success then
		refs.resTitle.Text = if r.medal then string.upper(r.medal) .. "!" else "JOB COMPLETE!"
		refs.resTitle.TextColor3 = colors.good
		refs.resReward.Text = string.format("+%s   +%d Rep", Theme.money(r.cash), r.rep)
	else
		refs.resTitle.Text = "JOB FAILED"
		refs.resTitle.TextColor3 = colors.bad
		refs.resReward.Text = if r.rep > 0 then string.format("+%d Rep", r.rep) else "No payout"
	end
	refs.resReason.Text = r.reason or ""
	task.delay(8, function()
		refs.result.Visible = false
	end)
end

function HUD.start()
	build()
	Store.on("state", renderState)
	Store.on("job", renderJob)
	Store.on("toast", toast)
	Store.on("jobResult", showResult)
	renderState(Store.state)
	RunService.RenderStepped:Connect(function()
		local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		if seat and seat:IsA("VehicleSeat") then
			local v = seat.AssemblyLinearVelocity
			-- shown in studs/s, the same unit as the car stats in the Car Lot
			refs.speed.Text = string.format("%d", math.floor(Vector3.new(v.X, 0, v.Z).Magnitude + 0.5))
			refs.speed.Visible = true
		else
			refs.speed.Visible = false
		end
	end)
end

return HUD
