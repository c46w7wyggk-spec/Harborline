--!strict
-- Vehicle purchases and the Noodle Stand business. All prices come from shared config;
-- the client only sends an id. Purchases require standing near the relevant shop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Layout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local TutorialService = require(script.Parent.TutorialService)
local Net = require(script.Parent.Net)

local SHOP_RADIUS = 40
local BUSINESS_TICK = 10

local ShopService = {}
local carry: { [Player]: number } = {}
local lastActive: { [Player]: number } = {}
local lastPos: { [Player]: Vector3 } = {}

local function near(player: Player, place: Layout.Point, radius: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return Layout.distance({ x = root.Position.X, z = root.Position.Z }, place) <= radius
end

function ShopService.markActive(player: Player)
	lastActive[player] = os.clock()
end

function ShopService.start()
	Net.on("BuyVehicle", function(player, arg)
		local p = DataService.profile(player)
		local def = Progression.vehicleById(arg)
		if not p or not def or not Validate.id(arg) then
			return false, "Unknown vehicle."
		end
		if not near(player, Layout.Places.CarLot, SHOP_RADIUS) then
			return false, "Visit the Car Lot in the plaza to buy vehicles."
		end
		local ok, err = Economy.buyVehicle(p, def.id)
		if not ok then
			return false, err
		end
		DataService.markDirty(player, true)
		StateService.push(player)
		return true, string.format("You bought the %s! Spawn it from Phone > Garage.", def.name)
	end)

	Net.on("UpgradeBusiness", function(player)
		local p = DataService.profile(player)
		if not p then
			return false, nil
		end
		if not near(player, Layout.Places.NoodleStand, SHOP_RADIUS) then
			return false, "Head to the Noodle Stand to upgrade it."
		end
		local ok, err = Economy.upgradeBusiness(p)
		if not ok then
			return false, err
		end
		carry[player] = 0
		DataService.markDirty(player, true)
		StateService.push(player)
		TutorialService.event(player, "buy")
		local lvl = Economy.businessLevel(p) :: Progression.BusinessLevel
		return true, string.format("Welcome to the %s! It earns $%d/min while you play.", lvl.name, lvl.incomePerMin)
	end)

	Net.on("CollectBusiness", function(player)
		local p = DataService.profile(player)
		if not p or p.business.level <= 0 then
			return false, "You don't own a business yet."
		end
		if not near(player, Layout.Places.NoodleStand, SHOP_RADIUS) then
			return false, "Collect your earnings at the Noodle Stand."
		end
		local amount = Economy.collectBusiness(p)
		if amount <= 0 then
			return false, "Nothing to collect yet."
		end
		DataService.markDirty(player, true)
		StateService.push(player)
		return true, string.format("Collected $%d from the till.", amount)
	end)

	Players.PlayerRemoving:Connect(function(player)
		carry[player] = nil
		lastActive[player] = nil
		lastPos[player] = nil
	end)

	-- Business income, freshness recovery and play time: only while online and active.
	task.spawn(function()
		while true do
			task.wait(BUSINESS_TICK)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local p = DataService.profile(player)
				if not p then
					continue
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local prev = lastPos[player]
					if prev and (root.Position - prev).Magnitude > 3 then
						lastActive[player] = now
					end
					lastPos[player] = root.Position
				end
				local active = lastActive[player] ~= nil
					and now - (lastActive[player] :: number) <= Progression.Business.activeWindow
				if not active then
					continue
				end
				p.stats.playSeconds += BUSINESS_TICK
				Economy.recoverFreshness(p, BUSINESS_TICK / 60)
				local before = p.business.stash
				carry[player] = Economy.tickBusiness(p, BUSINESS_TICK, carry[player] or 0)
				if p.business.stash ~= before then
					StateService.push(player)
				end
				DataService.markDirty(player)
			end
		end
	end)
end

return ShopService
