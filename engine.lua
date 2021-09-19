
local sqlite3 = sqlite3 or require("lsqlite3")

-- assert time calculations (os dependent)

assert(
	os.time{day = -1, month = 1, year = 2013}
	==
	os.time{day = 30, month = 12, year = 2012}
)

assert(
	os.time{day = 32, month = 12, year = 2012}
	==
	os.time{day = 1, month = 1, year = 2013}
)

local db, _, errmsg = sqlite3.open("database.sqlite3")
if not db then error(errmsg) end

local dateformat = "%Y-%m-%d"

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
	local result = query:step() == sqlite3.ROW and query:get_value(0) == task
	query:finalize()
	return result
end

-- return a table with options
local function get_options()
	local result = { }
	for name, value in db:urows("SELECT name, value FROM options;") do
		if name == "tag" then value = tonumber(value) end
		result[name] = value
	end
	return result
end

-- return true if d is a valid date else return nil or false
local function isdate(d)
	local t = { }
	t.year, t.month, t.day = d:match('(%d%d%d%d)-(%d%d)-(%d%d)')
	return t.year and t.month and t.day and
		os.date(dateformat, os.time(t)) == d
end

-- return true if d is an unespecified time
local function isanytime(d)
	return not d or d == '' or d == 'anytime'
end

-- return true if d is tomorrow
local function istomorrow(d)
	local tomorrow = os.date("*t")
	tomorrow.day = tomorrow.day + 1
	return d == os.date(dateformat, os.time(tomorrow))
end

-- return true if d is in the future but not tomorrow
local function isfuture(d)
	return not isanytime(d) and not istomorrow(d) and
		d > os.date(dateformat)
end

-- return true if d is today
local function istoday(d)
	return d == os.date(dateformat)
end

-- return true if d is yesterday
local function isyesterday(d)
	local yesterday = os.date("*t")
	yesterday.day = yesterday.day -1
	return d == os.date(dateformat, os.time(yesterday))
end

-- return true if d is in the past but not yesterday
local function islate(d)
	return not isanytime(d) and not isyesterday(d) and
		d < os.date(dateformat)
end

-- return the number of days in a month
local function daysmonth(month, year)
	while month > 12 do month = month - 12 end
	return month == 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) and 29
		or ('\31\28\31\30\31\30\31\31\30\31\30\31'):byte(month)
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
	db          = db,
	has_table   = has_table,
	has_id      = has_id,
	has_tag     = has_tag,
	get_options = get_options,
	isdate      = isdate,
	isanytime   = isanytime,
	istomorrow  = istomorrow,
	isfuture    = isfuture,
	istoday     = istoday,
	isyesterday = isyesterday,
	islate      = islate,
	daysmonth   = daysmonth,
}
