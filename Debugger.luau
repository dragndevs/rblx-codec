local HttpService = game:GetService("HttpService")

local debugger = {}

debugger.Enabled = true
debugger.ShowTimestamps = true

-- 1 = DEBUG, 2 = INFO, 3 = WARN, 4 = ERROR
debugger.MinLogLevel = 1 

-- Internal helper to format tags and optional timestamps
local function getPrefix(levelName: string, tag: string?): string
	local timestamp = ""
	if debugger.ShowTimestamps then
		timestamp = string.format("[%s] ", os.date("%X"))
	end

	if tag then
		return string.format("%s[%s] [%s]:", timestamp, levelName, string.upper(tag))
	else
		return string.format("%s[%s]:", timestamp, levelName)
	end
end

--[[
    Scans the accessible game services, totals every line of code, 
    and prints the user-requested string output format.
]]
function debugger.countLines()
	if not debugger.Enabled then return end

	local totalLines = 0
	local scriptCount = 0

	local servicesToScan = {
		game:GetService("Workspace"),
		game:GetService("ReplicatedFirst"),
		game:GetService("ReplicatedStorage"),
		game:GetService("ServerScriptService"),
		game:GetService("ServerStorage"),
		game:GetService("StarterGui"),
		game:GetService("StarterPlayer"),
		game:GetService("SoundService")
	}

	for _, service in ipairs(servicesToScan) do
		for _, descendant in ipairs(service:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
				local success, source = pcall(function()
					return descendant.Source
				end)

				if success and source then
					scriptCount = scriptCount + 1
					if source ~= "" then
						local _, lineCount = string.gsub(source, "\n", "\n")
						totalLines = totalLines + (lineCount + 1)
					end
				end
			end
		end
	end

	debugger.log("Metrics", string.format("This game has %d lines of code!", totalLines))
end

-- Verbose Debug Log (Level 1)
function debugger.debug(tag: string | any, ...: any)
	if not debugger.Enabled or debugger.MinLogLevel > 1 then return end

	if typeof(tag) == "string" and select("#", ...) > 0 then
		print(getPrefix("DEBUG", tag), "??", ...)
	else
		print(getPrefix("DEBUG"), "??", tag, ...)
	end
end

-- Standard Info Log (Level 2)
function debugger.log(tag: string | any, ...: any)
	if not debugger.Enabled or debugger.MinLogLevel > 2 then return end

	if typeof(tag) == "string" and select("#", ...) > 0 then
		print(getPrefix("INFO", tag), ...)
	else
		print(getPrefix("INFO"), tag, ...)
	end
end

-- Warning Log (Level 3)
function debugger.warn(tag: string | any, ...: any)
	if not debugger.Enabled or debugger.MinLogLevel > 3 then return end

	if typeof(tag) == "string" and select("#", ...) > 0 then
		warn(getPrefix("WARN", tag), ...)
	else
		warn(getPrefix("WARN"), tag, ...)
	end
end

-- Error Log (Level 4) - Does not crash the thread, just prints a highly visible stack trace
function debugger.error(tag: string | any, ...: any)
	if not debugger.Enabled then return end

	local message
	if typeof(tag) == "string" and select("#", ...) > 0 then
		message = string.format("%s %s", getPrefix("ERROR", tag), table.concat({ ... }, " "))
	else
		message = string.format("%s %s", getPrefix("ERROR"), table.concat({ tag, ... }, " "))
	end

	warn(string.format("\n?? ERROR DETECTED ??\n%s\n%s", message, debug.traceback()))
end

-- Cleanly pretty prints complex nested tables or dictionaries
function debugger.dump(label: string, tbl: { [any]: any })
	if not debugger.Enabled then return end
	assert(typeof(tbl) == "table", "[Debugger]: .dump() second argument must be a table.")

	print(getPrefix("DUMP"), string.format("--- TABLE INSPECTION: %s ---", string.upper(label)))
	local success, result = pcall(function()
		return HttpService:JSONEncode(tbl)
	end)

	if success then
		print(result)
	else
		for k, v in pairs(tbl) do
			print(string.format("  [%s] (%s) -> %s (%s)", tostring(k), typeof(k), tostring(v), typeof(v)))
		end
	end
	print(string.rep("-", 30))
end

-- Safe execution wrapper that profiles performance metrics
function debugger.profile(profileName: string, iterations: number, callback: (...any) -> any, ...: any): any
	if not debugger.Enabled then return callback(...) end

	local startTime = os.clock()
	local lastResult

	for i = 1, iterations do
		lastResult = callback(...)
	end

	local endTime = os.clock()
	local totalTimeMs = (endTime - startTime) * 1000
	local avgTimeMs = totalTimeMs / iterations

	print(getPrefix("PROFILE"), string.format("'%s' x%d iterations took %.4f ms (Avg: %.6f ms per run)", profileName, iterations, totalTimeMs, avgTimeMs))
	return lastResult
end

-- Non-breaking Assertion: Logs a severe warning/error if condition fails, without crashing script execution
function debugger.expect(condition: any, message: string, tag: string?): boolean
	if not condition then
		debugger.error(tag or "EXPECTATION FAILED", message)
		return false
	end
	return true
end

function debugger.test(testName: string, testFunc: () -> any)
	if not debugger.Enabled then return end

	print(string.format("\n?? RUNNING TEST: %s", string.upper(testName)))
	print(string.rep("-", 40))

	local startClock = os.clock()
	local success, result = pcall(testFunc)
	local endClock = os.clock()
	local durationMs = (endClock - startClock) * 1000

	if success then
		print(string.format("?? PASS: %s (Duration: %.3f ms)", testName, durationMs))
		if result ~= nil then
			print("   Returned Result:", result)
		end
	else
		warn(string.format("?? FAIL: %s (Duration: %.3f ms)", testName, durationMs))
		warn("   Error Info: " .. tostring(result))
	end
	print(string.rep("-", 40) .. "\n")
end

return debugger