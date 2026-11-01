--- @since 26.8.15

local M = {}

local function fail(job, s)
	ya.preview_widget(job, ui.Text.parse(s):area(job.area):wrap(ui.Wrap.YES))
end

function M:peek(job)
	if not job.file then
		return
	end

	local path = tostring(job.file.path or job.file.url):gsub("^file://", "")

	local child, err = Command("bat")
		:arg({
			"--color=always",
			"--style=plain",
			"--theme=x",
			"--paging=never",
			path,
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()

	if not child then
		return fail(job, "bat spawn error: " .. tostring(err))
	end

	local limit = job.area.h
	local i, lines, errs = 0, {}, {}
	repeat
		local next, event = child:read_line()
		if event == 1 then
			errs[#errs + 1] = next
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			lines[#lines + 1] = next
		end
	until i >= job.skip + limit

	child:start_kill()

	if #errs > 0 and #lines == 0 then
		fail(job, table.concat(errs, ""))
	elseif job.skip > 0 and i < job.skip + limit then
		ya.emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	else
		local tab_size = (rt and rt.preview and rt.preview.tab_size) or 2
		local text = table.concat(lines, ""):gsub("\t", string.rep(" ", tab_size))
		ya.preview_widget(job, ui.Text.parse(text):area(job.area))
	end
end

function M:seek(job)
	require("code"):seek(job)
end

return M
