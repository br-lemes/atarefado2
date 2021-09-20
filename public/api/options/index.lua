-- /options/
-- path_info not allowed

local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng)
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(eng.get_options()))
end

local function post(eng)
	local data, errmsg = eng.read_data{option = true, value = true}
	if not data then
		errno = 400
		error(errmsg, level)
	end
	local result
	result, errmsg = eng.set_options(data.option, data.value)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
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
