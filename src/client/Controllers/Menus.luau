--!strict
-- One modal "phone" with tabs: Jobs, Garage, Car Lot, Business.
-- Every button only sends a request; the server decides and replies with a toast.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local JobsConfig = require(ReplicatedStorage.Shared.Config.Jobs)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)

local new = Theme.new
local colors = Theme.colors

local Menus = {}
local root: Frame
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "jobs"
local TABS = { { "jobs", "Jobs" }, { "garage", "Garage" }, { "dealer", "Car Lot" }, { "business", "Business" } }

local function clearList()
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function card(title: string, lines: string, buttonText: string?, enabled: boolean, onClick: (() -> ())?, accent: Color3?): Frame
	-- grows with its text so long blurbs never spill into the next card
	local f = new("Frame", { Parent = list, BackgroundColor3 = colors.panelLight, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 104), AutomaticSize = Enum.AutomaticSize.Y })
	Theme.corner(12).Parent = f
	Theme.padding(10).Parent = f
	Theme.label({ Parent = f, Text = title, TextSize = 20, TextColor3 = accent or colors.text, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -130, 0, 22) })
	Theme.label({ Parent = f, Text = lines, Font = Theme.bodyFont, TextSize = 14, TextColor3 = colors.muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -130, 0, 50), AutomaticSize = Enum.AutomaticSize.Y })
	if buttonText then
		local b = Theme.button({
			Parent = f,
			Text = buttonText,
			TextSize = 17,
			BackgroundColor3 = if enabled then (accent or colors.accent) else colors.panel,
			TextColor3 = if enabled then Color3.fromRGB(10, 20, 30) else colors.muted,
			AutoButtonColor = enabled,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(120, Theme.MIN_TOUCH + 4),
		})
		b.Activated:Connect(function()
			if onClick then
				onClick()
			end
		end)
	end
	return f
end

local function ownedSet(s: any): { [string]: boolean }
	local set = {}
	for _, id in s.owned do
		set[id] = true
	end
	return set
end

local renderTab: () -> ()

local function renderJobs(s: any)
	for _, id in JobsConfig.Order do
		local def = JobsConfig.Jobs[id]
		local cd = Store.cooldownLeft(id)
		local fresh = s.freshness[id] or 1
		local status
		local enabled = true
		if s.level < def.repLevel then
			status = string.format("Unlocks at Rep level %d", def.repLevel)
			enabled = false
		elseif cd > 0 then
			status = string.format("Cooling down: %s", Theme.clock(cd))
			enabled = false
		elseif not s.firstRunDone[id] then
			status = "FIRST RUN PAYS 2x!"
		elseif def.usesFreshness and fresh < 0.99 then
			status = string.format("Pay %d%% (do other jobs to refresh)", math.floor(fresh * 100))
		else
			status = "Ready"
		end
		if def.requiresVehicle then
			status ..= "  - needs a vehicle"
		end
		card(def.name, def.blurb .. "\n" .. status, if Store.job then nil else "Start", enabled and not Store.job, function()
			if Store.request("StartJob", id) then
				Menus.close()
			end
		end, colors.rep)
	end
	if Store.job then
		card("On a job", "Finish or cancel your current job (X on the objective panel) to start another.", "Cancel job", true, function()
			Store.request("CancelJob")
			Menus.close()
		end, colors.bad)
	end
end

local function renderGarage(s: any)
	local owned = ownedSet(s)
	for _, v in Progression.Vehicles do
		if owned[v.id] then
			card(v.name, string.format("Top speed %d   Owned", v.maxSpeed), "Spawn", true, function()
				if Store.request("SpawnVehicle", v.id) then
					Menus.close()
				end
			end)
		end
	end
	card("Return vehicle", "Send your current car back to the garage.", "Return", true, function()
		Store.request("DespawnVehicle")
	end, colors.muted)
end

local function renderDealer(s: any)
	local owned = ownedSet(s)
	card("Car Lot", "Buy at the Car Lot kiosk in the plaza. Faster cars = better race medals and quicker deliveries.", nil, false, nil, colors.accent)
	for _, v in Progression.Vehicles do
		if v.price > 0 then
			local text
			local enabled = false
			if owned[v.id] then
				text = "Owned"
			elseif s.level < v.repLevel then
				text = string.format("Needs Rep level %d", v.repLevel)
			elseif s.cash < v.price then
				text = string.format("Need %s more", Theme.money(v.price - s.cash))
			else
				text = "Affordable!"
				enabled = true
			end
			card(
				string.format("%s  %s", v.name, Theme.money(v.price)),
				string.format("Top speed %d   %s", v.maxSpeed, text),
				if owned[v.id] then nil else "Buy",
				enabled,
				function()
					Store.request("BuyVehicle", v.id)
				end,
				colors.cash
			)
		end
	end
end

local function renderBusiness(s: any)
	local b = s.business
	if b.level > 0 then
		card(
			b.name,
			string.format("Earns %s/min while you play. Till: %s / %s", Theme.money(b.incomePerMin), Theme.money(b.stash), Theme.money(b.cap)),
			"Collect",
			b.stash > 0,
			function()
				Store.request("CollectBusiness")
			end,
			colors.cash
		)
	else
		card("Noodle Stand", "Own a noodle business on the plaza. It fills a till while you're online, and boosts Courier pay.", nil, false, nil, colors.pink)
	end
	if b.nextName then
		local enabled = s.cash >= b.nextCost and s.level >= b.nextRepLevel
		local need = if s.level < b.nextRepLevel then string.format("Needs Rep level %d", b.nextRepLevel) else (if enabled then "Affordable!" else string.format("Need %s more", Theme.money(b.nextCost - s.cash)))
		card(
			string.format("%s %s", if b.level > 0 then "Upgrade to" else "Buy", b.nextName),
			string.format("%s   %s\nManage at the Noodle Stand in the plaza.", Theme.money(b.nextCost), need),
			if b.level > 0 then "Upgrade" else "Buy",
			enabled,
			function()
				Store.request("UpgradeBusiness")
			end,
			colors.pink
		)
	else
		card("Fully upgraded", "Your noodle empire is complete.", nil, false, nil)
	end
end

function renderTab()
	if not root or not root.Visible then
		return
	end
	local hadSelection = GuiService.SelectedObject ~= nil and GuiService.SelectedObject:IsDescendantOf(root)
	clearList()
	for id, b in tabButtons do
		b.BackgroundColor3 = if id == currentTab then colors.accent else colors.panelLight
		b.TextColor3 = if id == currentTab then Color3.fromRGB(10, 20, 30) else colors.text
	end
	local s = Store.state
	if not s then
		card("Loading", "Your save is still loading...", nil, false, nil)
		return
	end
	if currentTab == "jobs" then
		renderJobs(s)
	elseif currentTab == "garage" then
		renderGarage(s)
	elseif currentTab == "dealer" then
		renderDealer(s)
	else
		renderBusiness(s)
	end
	if hadSelection then
		-- the selected card was rebuilt; keep gamepad focus inside the menu
		GuiService.SelectedObject = tabButtons[currentTab]
	end
end

local function build()
	local gui = new("ScreenGui", {
		Name = "HarborlineMenus",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	root = new("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.86, 0),
		BackgroundColor3 = colors.panel,
		BorderSizePixel = 0,
		Visible = false,
	})
	new("UISizeConstraint", { Parent = root, MaxSize = Vector2.new(560, 620) })
	Theme.corner(18).Parent = root
	Theme.padding(12).Parent = root

	local tabs = new("Frame", { Parent = root, BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, Theme.MIN_TOUCH) })
	new("UIListLayout", { Parent = tabs, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) })
	for _, t in TABS do
		local b = Theme.button({ Parent = tabs, Text = t[2], TextSize = 16, Size = UDim2.new(0.25, -5, 1, 0) })
		b.Activated:Connect(function()
			currentTab = t[1]
			renderTab()
		end)
		tabButtons[t[1]] = b
	end
	local close = Theme.button({ Parent = root, Text = "X", BackgroundColor3 = colors.bad, TextColor3 = colors.text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(Theme.MIN_TOUCH, Theme.MIN_TOUCH) })
	close.Activated:Connect(function()
		Menus.close()
	end)

	list = new("ScrollingFrame", {
		Parent = root,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Theme.MIN_TOUCH + 10),
		Size = UDim2.new(1, 0, 1, -(Theme.MIN_TOUCH + 10)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
	})
	new("UIListLayout", { Parent = list, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
end

function Menus.open(tab: string)
	if tab == "phone" then
		tab = "jobs"
	end
	currentTab = tab
	root.Visible = true
	renderTab()
	if Theme.isGamepad() then
		GuiService.SelectedObject = tabButtons[currentTab]
	end
end

function Menus.close()
	root.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
		GuiService.SelectedObject = nil
	end
end

function Menus.toggle(tab: string)
	if root.Visible then
		Menus.close()
	else
		Menus.open(tab)
	end
end

function Menus.isOpen(): boolean
	return root.Visible
end

function Menus.start()
	build()
	-- live cooldown countdown while the Jobs tab is open
	task.spawn(function()
		while true do
			task.wait(1)
			if root.Visible and currentTab == "jobs" and Store.state then
				for _, id in JobsConfig.Order do
					if (Store.state.cooldowns[id] or 0) > 0 and Store.cooldownLeft(id) >= 0 then
						renderTab()
						break
					end
				end
			end
		end
	end)
	Store.on("openMenu", function(id)
		Menus.open(id)
	end)
	Store.on("state", function()
		renderTab()
	end)
	local hadJob = false
	Store.on("job", function(msg)
		-- re-render only when a job starts or ends, not on every objective tick
		local hasJob = msg ~= nil
		if hasJob ~= hadJob then
			hadJob = hasJob
			renderTab()
		end
	end)
end

return Menus
