
local sqlite3 = sqlite3 or require("lsqlite3")

local db, _, errmsg = sqlite3.open("database.sqlite3")
if not db then error(errmsg) end

-- check if database has the given table
-- return: true or false
local function has_table(tname)
	local query = db:prepare(
		'SELECT name FROM sqlite_master WHERE type="table" AND name=?')
	if not query then error(db:errmsg()) end
	assert(query:bind_values(tname) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == tname
	query:finalize()
	return result
end

-- check if the given id has in the given table
-- return: true or false
local function has_id(id, tname)
	if not has_table(tname) then
		error(string.format("no such table: %s", tname))
	end
	local query = db:prepare(string.format(
		"SELECT id FROM %s WHERE id=?", tname))
	if not query then error(db:errmsg()) end
	assert(query:bind_values(id) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == id
	query:finalize()
	return result
end

-- check if the given task has the given tag
-- return: true or false
local function has_tag(task, tag)
	local query = db:prepare(
		"SELECT task FROM tags WHERE task=? and tag=?")
	if not query then error(db:errmsg()) end
	assert(query:bind_values(task, tag) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query.get_value(0) == task
	query:finalize()
	return result
end

assert(db:execute("BEGIN;"))
if not has_table("tagnames") then
	assert(db:execute([[
		CREATE TABLE tagnames (
			id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
			name TEXT NOT NULL
		);]]))
	for _, v in ipairs{
			"Dom", "Seg", "Ter", "Qua",
			"Qui", "Sex", "Sáb"
		} do
		assert(db:execute(string.format(
			"INSERT INTO tagnames VALUES(NULL, %q);", v)))
	end
	for i = 1, 31 do
		assert(db:execute(string.format(
			'INSERT INTO tagnames VALUES(NULL, "%02d");',
			i)))
	end
end

if not has_table("tags") then
	assert(db:execute([[
		CREATE TABLE tags (
			task INTEGER NOT NULL,
			tag INTEGER NOT NULL
		);]]))
end

if not has_table("tasks") then
	assert(db:execute([[
		CREATE TABLE tasks (
			id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
			name TEXT NOT NULL,
			date TEXT,
			comment TEXT,
			recurrent INTEGER NOT NULL
		);]]))
end

if not has_table("options") then
	assert(db:execute([[
		CREATE TABLE options (
			id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
			name TEXT NOT NULL,
			value TEXT
		);]]))
	local optfmt = "INSERT INTO options VALUES(NULL, %q, %q);"
	for _, v in ipairs{
			"anytime", "tomorrow", "future",
			"today", "yesterday", "late"
		} do
		assert(db:execute(string.format(optfmt, v, "ON")))
	end
	assert(db:execute(string.format(optfmt, "tag", "1")))
	assert(db:execute(string.format(optfmt, "version", "1")))
end
assert(db:execute("END;"))

return {
	db         = db,
	has_table  = has_table,
	has_id     = has_id,
	has_tag    = has_tag,
}
