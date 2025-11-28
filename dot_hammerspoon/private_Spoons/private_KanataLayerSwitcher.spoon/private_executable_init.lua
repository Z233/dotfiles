local obj = {}
obj.__index = obj

-- Metadata
obj.name = "KanataLayerSwitcher"
obj.version = "1.0"
obj.author = "Fronz"
obj.homepage = "https://github.com/fronz/KanataLayerSwitcher.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.kanataPath = "/opt/homebrew/bin/kanata"
obj.configPath = "/Users/fronz/OneDrive/Config/kanata/fronz.kbd"

-- Add near the top of the file with other object properties
obj.kanataArgs = {
	"-n",
	"-p 9999",
}

local hsSocket = require("hs.socket")
local json = require("hs.json")

obj.layers = {
	default = "default",
	nvim = "nvim",
}

obj.appLayerMap = {
	Cursor = obj.layers.nvim,
	Code = obj.layers.nvim,
	-- Add more app-to-layer mappings here
}

obj.currentLayer = obj.layers.default
obj.socket = nil

function obj:setLayer(newLayer)
	if self.currentLayer ~= newLayer then
		self.currentLayer = newLayer
		print("Layer changed to: " .. newLayer)

		-- Check if socket is connected
		if not self.socket or not self.socket:connected() then
			print("Socket is not connected. Attempting to reconnect...")
			self:connectToServer(function()
				print("Reconnected to server. Retrying layer change.")
				self:setLayer(newLayer) -- Retry setting the layer after reconnection
			end)
		else
			-- Send layer change request to the server
			local message = json.encode({ ChangeLayer = { new = newLayer } })
			self.socket:send(message .. "\n")
		end
	end
end

function obj:onWindowFocused(appName)
	print("Window focused: " .. appName)
	local newLayer = self.appLayerMap[appName] or self.layers.default
	self:setLayer(newLayer)
end

function obj:handleServerMessage(message)
	if message.layerChange then
		local newLayer = message.layerChange.new
		print("Server changed layer to: " .. newLayer)
		self.currentLayer = newLayer
	else
		print("Received unknown message type from server")
	end
end

function obj:readFromServer()
	self.socket:setCallback(function(data, errorMessage)
		if data then
			local messages = {}
			for message in data:gmatch("[^\n]+") do
				table.insert(messages, message)
			end

			for _, message in ipairs(messages) do
				local success, parsedMessage = pcall(json.decode, message)
				if success then
					self:handleServerMessage(parsedMessage)
				else
					print("Error parsing server message: " .. message)
				end
			end
		elseif errorMessage then
			print("Error receiving data: " .. errorMessage)
			-- Attempt to reconnect
			self.socket:disconnect()
			hs.timer.doAfter(5, function()
				self:connectToServer()
			end)
		end
	end)
end

function obj:connectToServer(callback)
	if self.socket then
		self.socket:disconnect()
	end

	self.socket = hsSocket.new()

	self.socket:setTimeout(5) -- Set timeout for connection
	self.socket:connect("localhost", 9999, function()
		if self.socket:connected() then
			print("Connected to TCP server")
			-- Start reading from the server
			self:readFromServer()

			-- Call the callback function if provided
			if callback and type(callback) == "function" then
				callback()
			end
		else
			hs.alert.show("Failed to connect to TCP server")
			print("Failed to connect to TCP server")
			-- Retry connection after a delay
			hs.timer.doAfter(5, function()
				self:connectToServer(callback)
			end)
		end
	end)
end

function obj:isKanataRunning()
	local output, status = hs.execute("pgrep kanata")
	return status == true
end

function obj:startKanata()
	if not self.configPath then
		print("Error: Kanata config path not set")
		return false
	end

	-- Build arguments string
	local args = table.concat(self.kanataArgs, " ") .. " -c " .. self.configPath

	-- Added sudo to the command
	local script = [[
        try
            set pid to (do shell script "sudo ]] .. self.kanataPath .. " " .. args .. [[ > /tmp/kanata.log 2>&1 & echo $!")
            set output to (do shell script "tail -n 5 /tmp/kanata.log")
            return {true, "Kanata started successfully (PID: " & pid & "). Output: " & output}
        on error errMsg
            return {false, errMsg}
        end try
    ]]

	local success, output, rawOutput = hs.osascript.applescript(script)

	if success then
		local ok, cmdOutput = table.unpack(output)
		if ok then
			print("Kanata start command output: " .. cmdOutput)
			return true
		else
			print("Failed to start Kanata: " .. cmdOutput)
			return false
		end
	else
		print("AppleScript error: " .. (output or "unknown error"))
		return false
	end
end

function obj:stopKanata()
	-- Added sudo to the command
	local script = [[
        try
            do shell script "sudo pkill kanata"
            return {true, "Kanata stopped successfully"}
        on error errMsg
            return {false, errMsg}
        end try
    ]]

	local success, output, rawOutput = hs.osascript.applescript(script)

	if success then
		local ok, cmdOutput = table.unpack(output)
		if ok then
			print("Kanata stop command output: " .. cmdOutput)
			return true
		else
			print("Failed to stop Kanata: " .. cmdOutput)
			return false
		end
	else
		print("AppleScript error: " .. (output or "unknown error"))
		return false
	end
end

function obj:ensureKanataRunning()
	if self:isKanataRunning() then
		print("Kanata is already running, restarting...")
		if not self:stopKanata() then
			print("Failed to stop existing Kanata process")
			return false
		end
		-- Small delay to ensure process is fully stopped
		hs.timer.usleep(500000) -- 500ms delay
	end

	print("Starting Kanata...")
	return self:startKanata()
end

function obj:start()
	-- Check and start Kanata if needed
	-- if not self:ensureKanataRunning() then
	--     hs.alert.show("Failed to start Kanata")
	--     return
	-- end

	-- Monitor the active window with hs.window.filter
	local wf = hs.window.filter.new(nil)

	-- Subscribe to window focus changes
	wf:subscribe(hs.window.filter.windowFocused, function(window)
		local appName = window:application():name()
		self:onWindowFocused(appName)
	end)

	self:connectToServer(function()
		hs.alert.show("Kanata application-aware switcher is running...")
	end)
end

return obj
