--- @since 26.8.15

local M = {}

local function fail(job, s) ya.preview_widget(job, ui.Text.parse(s):area(job.area):wrap(ui.Wrap.YES)) end

local function theme()
	local light = rt.term.light()
	return light == true and "light" or light == false and "dark" or "auto"
end

function M:peek(job)
	if not job.file then
		return
	end

	local path = tostring(job.file.path or job.file.url):gsub("^file://", "")

	local cmd
	if type(job.args) == "table" and #job.args > 1 then
		cmd = table.concat(job.args, " ")
	else
		cmd = job.args[1] or ""
	end

	if not cmd:find("%$1") and not cmd:find("%$@") then
		cmd = cmd .. ' "$1"'
	end

	local child, err = Command("sh")
		:arg({ "-c", cmd, "sh", path })
		:env("w", job.area.w)
		:env("h", job.area.h)
		:env("t", theme())
		:env("CYGWIN", "noupcaseenv")
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()

	if not child then
		return fail(job, "sh: " .. tostring(err))
	end

	local limit = job.area.h
	local i, outs, errs = 0, {}, {}
	repeat
		local next, event = child:read_line()
		if event == 1 then
			errs[#errs + 1] = next
		elseif event ~= 0 then
			break
		else
			i = i + 1
			if i > job.skip then
				outs[#outs + 1] = next
			end
		end
	until i >= job.skip + limit

	child:start_kill()
	if #errs > 0 and #outs == 0 then
		fail(job, table.concat(errs, ""))
	elseif job.skip > 0 and i < job.skip + limit then
		ya.emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	else
		ya.preview_widget(job, M.format(job, outs))
	end
end

function M:seek(job) require("code"):seek(job) end

function M.format(job, lines)
	local format = job.args.format
	if format ~= "url" then
		local s = table.concat(lines, ""):gsub("\t", string.rep(" ", rt.preview.tab_size))
		return ui.Text.parse(s):area(job.area)
	end

	for i = 1, #lines do
		lines[i] = lines[i]:gsub("[\r\n]+$", "")

		Stat = Stat or Cha -- TODO: remove
		local stat = Stat { mode = tonumber(lines[i]:sub(-1) == "/" and "40700" or "100644", 8) }
		local icon = th.icon:match(File {
			url = Url(lines[i]),
			cha = stat, -- TODO: remove
			stat = stat,
			lstat = stat,
		})

		if icon then
			lines[i] = ui.Line { ui.Span(" " .. icon.text .. " "):style(icon.style), lines[i] }
		end
	end
	return ui.Text(lines):area(job.area)
end

return M
