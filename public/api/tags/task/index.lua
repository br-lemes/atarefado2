-- /tags/task/(%d+)/?
-- path_info required

local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local json = require("json")

local function get(eng, id)
	if not eng.has_id(id, 'tasks') then
		errno = 404
		error("Not found", level)
	end
	local result = { }
	for tag in eng.db:urows(string.format(
		"SELECT tag FROM tags WHERE task=%d;", id)) do
		table.insert(result, tag)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), json.encode(result))
end

local function post(eng, id)
	if not eng.has_id(id, 'tasks') then
		errno = 404
		error("Not found", level)
	end
	if mg.request_info.content_length > 1024 then
		errno = 400
		error("Too large data", level)
	end
	local request_body = mg.read()
	if not request_body then
		errno = 400
		error("No data", level)
	end
	local data = json.decode(request_body)
	if not data or type(data) ~= "table" or #data == 0 then
		errno = 400
		error("Invalid data", level)
	end
	for k, v in pairs(data) do
		if type(k) ~= "number" then
			errno = 400
			error("Invalid data", level)
		end
		if not eng.has_id(v, 'tagnames') then
			errno = 400
			error("Invalid tag", level)
		end
		if eng.has_tag(id, v) then
			errno = 400
			error("Already tagged", level)
		end
	end
	for _, v in ipairs(data) do
		eng.db:execute(string.format(
			"INSERT INTO tags VALUES(%d, %d);", id, v))
	end
	get(eng, id)
end

local function delete(eng, id)
	if not eng.has_id(id, 'tasks') then
		errno = 404
		error("Not found", level)
	end
	if mg.request_info.content_length > 1024 then
		errno = 400
		error("Too large data", level)
	end
	local request_body = mg.read()
	if not request_body then
		errno = 400
		error("No data", level)
	end
	local data = json.decode(request_body)
	if not data or type(data) ~= "table" or #data == 0 then
		errno = 400
		error("Invalid data", level)
	end
	for k, v in pairs(data) do
		if type(k) ~= "number" then
			errno = 400
			error("Invalid data", level)
		end
		if not eng.has_id(v, 'tagnames') then
			errno = 400
			error("Invalid tag", level)
		end
		if not eng.has_tag(id, v) then
			errno = 400
			error("Not tagged", level)
		end
	end
	for _, v in ipairs(data) do
		eng.db:execute(string.format(
			"DELETE FROM tags WHERE task=%d AND tag=%d;", id, v))
	end
	get(eng, id)
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
