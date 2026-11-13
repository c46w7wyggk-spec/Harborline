--!strict
-- Shared look and small UI construction helpers. Touch targets are at least 48 px tall.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

Theme.colors = {
	panel = Color3.fromRGB(22, 24, 36),
	panelLight = Color3.fromRGB(38, 42, 60),
	text = Color3.fromRGB(245, 245, 250),
	muted = Color3.fromRGB(170, 175, 195),
	cash = Color3.fromRGB(120, 230, 120),
	rep = Color3.fromRGB(255, 200, 70),
	accent = Color3.fromRGB(60, 210, 255),
	pink = Color3.fromRGB(255, 90, 160),
	warn = Color3.fromRGB(255, 150, 70),
	bad = Color3.fromRGB(240, 80, 80),
	good = Color3.fromRGB(90, 220, 130),
}
Theme.font = Enum.Font.FredokaOne
Theme.bodyFont = Enum.Font.GothamMedium
Theme.MIN_TOUCH = 48

function Theme.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Theme.isGamepad(): boolean
	return UserInputService.GamepadEnabled and GuiService:IsTenFootInterface()
		or UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
end

function Theme.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Theme.corner(radius: number?): UICorner
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.padding(px: number): UIPadding
	return Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Theme.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.font,
		TextColor3 = Theme.colors.text,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
	}
	for k, v in props do
		base[k] = v
	end
	return Theme.new("TextLabel", base)
end

function Theme.button(props: { [string]: any }): TextButton
	local base = {
		BackgroundColor3 = Theme.colors.accent,
		Font = Theme.font,
		TextColor3 = Color3.fromRGB(10, 20, 30),
		TextSize = 20,
		AutoButtonColor = true,
		Selectable = true,
		Size = UDim2.new(1, 0, 0, Theme.MIN_TOUCH),
	}
	for k, v in props do
		base[k] = v
	end
	local b = Theme.new("TextButton", base)
	Theme.corner(10).Parent = b
	return b
end

function Theme.money(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

function Theme.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Theme
