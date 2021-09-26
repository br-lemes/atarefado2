-- /tasks/(%d+)/?
-- path_info optional

local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng, id)
	local result, errmsg = eng.get_tasks(id)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function post(eng, id)
	local data, errmsg = eng.read_data{
		comment = true, date = true, name = true, recurrent = true}
	if not data then
		errno = 400
		error(errmsg, level)
	end
	local result
	result, errmsg = eng.set_tasks(id, data)
	if not result then
		errno = 400
		error(errmsg, level)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function delete(eng, id)
	if not eng.has_id(id, 'tasks') then
		errno = 400
		error("Invalid task", level)
	end
	local task
	for row in eng.db:nrows(string.format(
		"SELECT * FROM tasks WHERE id=%d;", id)) do
		task = row
	end
	if task.recurrent == 1 then
		eng.db:execute(string.format("DELETE FROM tags WHERE task=%d", id))
		eng.db:execute(string.format("DELETE FROM tasks WHERE id=%d", id))
		mg.send_http_ok(mg.get_mime_type("type.json"), "[]")
	else
		error("Not implemented")
	end
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
