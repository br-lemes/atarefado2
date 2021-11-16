
local M = {}

local shell = require("shell")

M.OK    = {true, "exit", 0}
M.ERROR = {nil, "exit", 4}

M.cmd   = ""
M.count = 0
M.pass  = 0

M.method = {
	GET    = true,
	POST   = true,
	DELETE = true,
}

function M.run(name, func)
	M.count = M.count + 1
	xpcall(function()
		func()
		print(string.format("[pass] %s", name))
		M.pass = M.pass + 1
	end, function(err)
		if M.cmd ~= "" then print(M.cmd) end
		print(string.format("[fail] %s: %s", name, err))
	end)
end

function M.equal(a, b)
	-- Handle table
	if type(a) == "table" and type(b) == "table" then
		for k in pairs(a) do
			if not M.equal(a[k], b[k]) then
				return false
			end
		end
		for k in pairs(b) do
			if not M.equal(b[k], a[k]) then
				return false
			end
		end
		return true
	end
	-- Handle scalar
	return a == b
end

function M.api(method, route, expected, filename, params)
	M.run(string.format("%s %s", method, route), function()
		assert(M.method[method])
		assert(type(M.host) == "string")
		assert(type(route) == "string")
		local url = M.host .. route
		local session = ""
		if M.session then
			assert(type(M.session) == "string")
			session = "--session=" .. M.session
		end
		local run = {
			"http", "--check-status", "--ignore-stdin", "--timeout=2.5",
			"--pretty=format", "--sorted", "-b", session, method, url
		}
		if params then
			if type(params) == "table" then
				for k, v in pairs(params) do
					if method == "GET" then
						table.insert(run, string.format("%s==%s", k, v))
					else
						table.insert(run, string.format("%s=%s", k, v))
					end
				end
			else
				table.insert(run, string.format("--raw=%s", params))
			end
		end
		M.cmd = string.format("%s | sed '/\\s\"refresh_at\": \".*\",$/d' > %s",
			shell.escape(run), filename)
		local result, output = shell.run(run)
		for i = 1, 3 do
			assert(result[i] == expected[i],
				string.format("result[%d]: expected '%s', got '%s'",
				i, expected[i], result[i]))
		end
		if filename then
			local h = assert(io.open(filename, "r"))
			local buffer = assert(h:read("a"))
			h:close()
			output = output:gsub('\n%s*"refresh_at": "[^"]*",\n', '\n')
			if output ~= buffer then
				h = assert(io.popen(string.format("diff -u %s - | diff-so-fancy",
					filename), "w"))
				assert(h:write(output))
				h:close()
				assert(nil, "api output differ!")
			end
		end
	end)
end

function M.total()
	print(string.format("%d tests (%d passed, %d failed)", M.count, M.pass, M.count - M.pass))
end

return M
