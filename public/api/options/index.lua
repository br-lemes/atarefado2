
local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng)
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(eng.get_options()))
end

local function post(eng)
	local ON_OFF = { ON = true, OFF = true }
	local valid_options = {
		anytime   = true,
		tomorrow  = true,
		future    = true,
		today     = true,
		yesterday = true,
		late      = true,
		tag       = true,
	}
	local request_body = mg.read()
	if not request_body then
		errno = 400
		error("No data", level)
	end
	if #request_body > 1024 then
		errno = 400
		error("Too large data", level)
	end
	local data = json.decode(request_body)
	for k, _ in pairs(data) do
		if k ~= "option" and k ~= "value" then
			errno = 400
			error("Invalid data", level)
		end
	end
	if not valid_options[data.option] then
		errno = 400
		error("Invalid option", level)
	end
	if data.option == "tag" then
		data.value = tostring(data.value)
		if not data.value:find("^%d+$") then
			errno = 400
			error("Invalid value", level)
		end
	else
		if not ON_OFF[data.value] then
			errno = 400
			error("Invalid value", level)
		end
	end
	eng.db:execute(string.format(
		"UPDATE options SET value=%q WHERE name=%q;",
		data.value, data.option))
	get(eng)
end

local method = { GET = get, POST = post }

local status, errmsg = pcall(function()
	if mg.request_info.path_info then
		errno = 404
		error("Not found", level)
	end
	if not method[mg.request_info.request_method] then
		errno = 405
		error("Method not allowed", level)
	end
	method[mg.request_info.request_method](require("engine"))
end)
if not status then mg.send_http_error(errno, errmsg) end
