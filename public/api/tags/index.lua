-- /tags/(%d+)/?
-- path_info optional

local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng, id)
	local result, errmsg = eng.get_tags(id)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	if id and #result == 0 then
		errno = 404
		error("Not found", level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function post(eng, id)
	local data, errmsg = eng.read_data{name = true}
	if not data then
		errno = 400
		error(errmsg, level)
	end
	local result
	result, errmsg = eng.set_tags(data.name, id)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function delete(eng, id)
	if id <= 38 then
		errno = 400
		error("Invalid tag")
	end
	if not eng.has_id(id, "tagnames") then
		errno = 400
		error("Invalid tag")
	end
	for row in eng.db:nrows("SELECT id FROM tasks;") do
		eng.db:execute(string.format(
			"DELETE FROM tags WHERE task=%d and tag=%d;",
			row.id, id))
	end
	eng.db:execute(string.format("DELETE FROM tagnames WHERE id=%d;", id))
	get(eng)
end

local method = { GET = get, POST = post, DELETE = delete }

local status, errmsg = pcall(function()
	if not method[mg.request_info.request_method] then
		errno = 405
		error("Method not allowed", level)
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
