-- mod-version:2 -- lite-xl 2.00
local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"
local Doc = require "core.doc"
local StatusView = require "core.statusview"

-- maximum size of git blame to read, multiplied by current filesize
config.max_blame_size = 100

local current_blame = {}
local current_file = {
    name = nil,
    is_in_repo = nil
}
local blames = {}

local function parse_blame(raw_blame)
	local results = {}
	local i = 0
	local str = ""
	for s in raw_blame:gmatch("[^\r\n]+") do
		if i % 13 == 0 then
			str = "#" .. s:sub(0, 7)
		end
		if i % 13 == 1 then
			str = str .. " " .. s:gsub("author ", "")
		end
		if i % 13 == 12 then
			table.insert(results, str)
		end
		i = i + 1
	end
	return results
end

local function update_blame()
	local current_doc = core.active_view.doc
	if current_doc == nil or current_doc.filename == nil then return end
	current_doc = system.absolute_path(current_doc.filename)

	core.log_quiet("updating blame for " .. current_doc)

	if current_file.is_in_repo ~= true then
		local is_in_repo = process.start({"git", "ls-files", "--error-unmatch", current_doc})
		is_in_repo:wait(10)
		is_in_repo = is_in_repo:returncode()
		is_in_repo = is_in_repo == 0
		current_file.is_in_repo = is_in_repo
	end
	if not current_file.is_in_repo then
		core.log_quiet("file ".. current_doc .." is not in a git repository")
		return
    end

	local max_blame_size = system.get_file_info(current_doc).size * config.max_blame_size
	local blame_proc = process.start({"git", "blame", "--line-porcelain", current_doc})
	blame_proc:wait(100)
	local raw_blame = blame_proc:read_stdout(max_blame_size)
	local parsed_blame = parse_blame(raw_blame)
	current_blame = parsed_blame
end

local function set_doc(doc_name)
	if current_blame ~= {} and current_file.name ~= nil then
	blames[current_file.name] = {
		data = current_blame,
		is_in_repo = current_file.is_in_repo
	}
	end
	current_file.name = doc_name
	if blames[current_file.name] ~= nil then
		current_blame = blames[current_file.name].data
		current_file.is_in_repo = blames[current_file.name].is_in_repo
	else
		current_blame = {}
		current_file.is_in_repo = nil
	end
	update_blame()
end

local status_view_get_items = StatusView.get_items
function StatusView:get_items()
	local left, right = status_view_get_items(self)

	if current_blame ~= {} then
		local doc = core.active_view.doc
		if doc == nil then return left, right end
		local line, col = doc:get_selection()
		local message = current_blame[line]
		if message == nil then return left, right end

		local t = {
			style.dim,
			self.separator2,
			style.text,
			style.icon_font, "i",
			style.font, " " .. tostring(message),
		}
		for i, item in ipairs(t) do
			table.insert(left, item)
		end
	end

 	return left, right
end

local old_docview_update = DocView.update
function DocView:update()
	local filename = self.doc.abs_filename or ""
	if current_file.name ~= filename and filename ~= "---" and core.active_view.doc == self.doc then
		set_doc(filename)
	end
	return old_docview_update(self)
end

local old_doc_save = Doc.save
function Doc:save(...)
	old_doc_save(self, ...)
	update_blame()
end
