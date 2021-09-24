-- /tags/task/(%d+)/?
-- path_info required

local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng, id)
	local result, errmsg = eng.get_tags_task(id)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function post(eng, id)
	local data, errmsg = eng.read_data()
	if not data then
		errno = 400
		error(errmsg, level)
	end
	local result
	result, errmsg = eng.set_tags_task(id, data)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function delete(eng, id)
	local data, errmsg = eng.read_data()
	if not data then
		errno = 400
		error(errmsg, level)
	end
	local result
	result, errmsg = eng.del_tags_task(id, data)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local method = { GET = get, POST = post, DELETE = delete }

local status, errmsg = pcall(function()
	if not method[mg.request_info.request_method] then
		errno = 405
		error("Method not allowed", level)
	end
	if not mg.request_info.path_info then
		errno = 404
		error("Not found", level)
	end
	local id
	if mg.request_info.path_info then
		id = tonumber(string.match(mg.request_info.path_info, ("^/(%d+)/?$")))
		if not id then
			errno = 404
			error("Not found", level)
		end
	end
	method[mg.request_info.request_method](require("engine"), id)
end)
if not status then mg.send_http_error(errno, errmsg) end
