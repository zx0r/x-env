--- @since 26.8.15

local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

return {
	entry = function()
		local cwd = get_cwd()
		local output, err = Command("git"):arg("-C"):arg(cwd):arg("rev-parse"):arg("--show-toplevel"):output()
		if output and output.status.success then
			local root = output.stdout:gsub("%s+$", "")
			if root ~= "" and root ~= cwd then
				ya.emit("cd", { root })
			end
		else
			ya.notify {
				title = "Git Root",
				content = "Not in a git repository",
				level = "warn",
				timeout = 3,
			}
		end
	end,
}
