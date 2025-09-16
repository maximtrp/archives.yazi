-- Archives plugin for Yazi file manager
-- Handles compression and extraction of various archive formats

local unpack = table.unpack or unpack

-- Archive format configurations
local ARCHIVE_FORMATS = {
	-- TAR-based compressed formats
	tar_bz2 = {
		patterns = { "%.tar%.bz2$", "%.tbz2?$" },
		compression_tools = { "pbzip2", "lbzip2", "bzip2" },
		tar_flag = "-cjf",
		requires_tar = true,
	},
	tar_gz = {
		patterns = { "%.tar%.gz$", "%.tgz$", "%.taz$" },
		compression_tools = { "pigz", "gzip" },
		tar_flag = "-czf",
		requires_tar = true,
	},
	tar_xz = {
		patterns = { "%.tar%.xz$", "%.txz$", "%.tlz$" },
		compression_tools = { "pixz", "xz" },
		tar_flag = "-cJf",
		requires_tar = true,
	},
	tar_lz4 = {
		patterns = { "%.tar%.lz4$" },
		compression_tools = { "lz4" },
		requires_tar = true,
	},
	tar_lrz = {
		patterns = { "%.tar%.lrz$" },
		compression_tools = { "lrzip" },
		requires_tar = true,
	},
	tar_lz = {
		patterns = { "%.tar%.lz$" },
		compression_tools = { "plzip", "lzip" },
		requires_tar = true,
	},
	tar_lzop = {
		patterns = { "%.tar%.lzop$", "%.tzo$" },
		compression_tools = { "lzop" },
		requires_tar = true,
	},
	tar_zst = {
		patterns = { "%.tar%.zst$" },
		compression_tools = { "zstd" },
		tar_flag = "--zstd",
		fallback_flag = "-cf",
		requires_tar = true,
	},
	tar = {
		patterns = { "%.tar$" },
		tar_flag = "-cf",
		fallback_tools = { "7z" },
		requires_tar = true,
	},

	-- Single-file compression formats
	bz2 = {
		patterns = { "%.bz2$" },
		compression_tools = { "pbzip2", "lbzip2", "bzip2" },
		single_file = true,
	},
	gz = {
		patterns = { "%.gz$" },
		compression_tools = { "pigz", "gzip" },
		single_file = true,
	},
	xz = {
		patterns = { "%.xz$", "%.lzma$" },
		compression_tools = { "pixz", "xz" },
		single_file = true,
	},
	lz = {
		patterns = { "%.lz$" },
		compression_tools = { "plzip", "lzip" },
		single_file = true,
	},
	lzop = {
		patterns = { "%.lzop$" },
		compression_tools = { "lzop" },
		special_handling = "convert_to_tar",
	},

	-- Archive formats
	seven_zip = {
		patterns = { "%.7z$" },
		tools = { "7z", "7za" },
		compress_args = { "a", "-r" },
	},
	rar = {
		patterns = { "%.rar$" },
		tools = { "rar" },
		compress_args = { "a", "-r" },
	},
	zip = {
		patterns = { "%.zip$" },
		tools = { "zip" },
		compress_args = { "-r" },
		fallback_tools = { "7z", "7za" },
	},
	zpaq = {
		patterns = { "%.zpaq$" },
		tools = { "zpaq" },
		compress_args = { "a" },
	},
}

local EXTRACTION_FORMATS = {
	-- TAR formats (including compressed)
	tar_compressed = {
		patterns = {
			"%.tar%.bz2$",
			"%.tar%.gz$",
			"%.tar%.lz4$",
			"%.tar%.lzma$",
			"%.tar%.lrz$",
			"%.tar%.lzop$",
			"%.tar%.xz$",
			"%.tar%.zst$",
			"%.tbz2?$",
			"%.tgz$",
			"%.txz$",
			"%.tlz$",
			"%.tzo$",
		},
		command = "tar",
		args = { "-xf" },
		output_flag = "-C",
	},
	tar = {
		patterns = { "%.tar$" },
		command = "tar",
		args = { "-xf" },
		output_flag = "-C",
		fallback = { tool = "7z", args = { "x" }, output_flag = "-o" },
	},

	-- Single-file compression that might be tar
	ambiguous_compressed = {
		patterns = { "%.gz$", "%.bz2$", "%.xz$", "%.lz$", "%.lzop$" },
		check_tar = true,
		single_file_tools = {
			["%.gz$"] = { "gzip", "pigz" },
			["%.bz2$"] = { "bzip2", "pbzip2", "lbzip2" },
			["%.xz$"] = { "xz", "pixz" },
			["%.lz$"] = { "lzip", "plzip" },
			["%.lzop$"] = { "lzop" },
		},
	},

	-- Standard archive formats
	seven_zip = {
		patterns = { "%.7z$" },
		command = "7z",
		args = { "x" },
		output_flag = "-o",
		fallback = { tool = "7za", args = { "x" }, output_flag = "-o" },
	},
	rar = {
		patterns = { "%.rar$" },
		tools = { "rar", "unrar" },
		args = { "x" },
		output_flag = "",
		fallback = { tool = "7z", args = { "x" }, output_flag = "-o" },
	},
	zip = {
		patterns = { "%.zip$" },
		command = "7z",
		args = { "x" },
		output_flag = "-o",
		fallback = { tool = "unzip", args = {}, output_flag = "-d" },
	},
	zpaq = {
		patterns = { "%.zpaq$" },
		command = "zpaq",
		args = { "x" },
		output_flag = "-to",
	},
	deb = {
		patterns = { "%.deb$" },
		command = "ar",
		args = { "xv" },
		output_flag = "--output=",
	},
}

-- Utility functions
local function is_command_available(cmd)
	if not cmd or cmd == "" then
		return false
	end

	local output = Command("which"):arg(cmd):output()
	return output and output.status.success
end

local function find_available_tool(tools)
	if not tools then
		return nil
	end

	for _, tool in ipairs(tools) do
		if is_command_available(tool) then
			return tool
		end
	end
	return nil
end

local function get_file_extension(filename)
	return filename:lower()
end

local function match_format_patterns(filename, patterns)
	local ext = get_file_extension(filename)
	for _, pattern in ipairs(patterns) do
		if ext:match(pattern) then
			return true
		end
	end
	return false
end

local function find_archive_format(filename, format_table)
	for format_name, config in pairs(format_table) do
		if match_format_patterns(filename, config.patterns) then
			return format_name, config
		end
	end
	return nil, nil
end

-- Path utilities
local function convert_to_relative_paths(files, base_dir)
	local base_url = Url(base_dir)
	local relative_files = {}

	for i, file_path in ipairs(files) do
		local file_url = Url(file_path)
		local relative_url = file_url:strip_prefix(base_url)
		relative_files[i] = tostring(relative_url)
	end

	return relative_files
end

-- Yazi context access functions
local get_selected_files = ya.sync(function()
	local paths = {}
	for _, u in pairs(cx.active.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and cx.active.current.hovered then
		paths[1] = tostring(cx.active.current.hovered.url)
	end
	return paths
end)

local get_current_directory = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

-- Command builders
local function build_tar_command_with_compression(archive_name, files, compression_tool)
	if not is_command_available("tar") then
		return nil
	end

	return { "tar", "-cf", archive_name, "--use-compress-program", compression_tool, unpack(files) }
end

local function build_single_file_compression_command(archive_name, files, compression_tool)
	if #files == 1 then
		return { compression_tool, "-c", files[1] }
	end

	-- Convert to tar format for multiple files
	local tar_name = archive_name
	local ext = get_file_extension(archive_name)

	if ext:match("%.gz$") then
		tar_name = archive_name:gsub("%.gz$", ".tar.gz")
	elseif ext:match("%.bz2$") then
		tar_name = archive_name:gsub("%.bz2$", ".tar.bz2")
	elseif ext:match("%.xz$") then
		tar_name = archive_name:gsub("%.xz$", ".tar.xz")
	elseif ext:match("%.lz$") then
		tar_name = archive_name:gsub("%.lz$", ".tar.lz")
	else
		tar_name = archive_name .. ".tar"
	end

	return build_tar_command_with_compression(tar_name, files, compression_tool)
end

local function build_compression_command(archive_name, files)
	local format_name, format_config = find_archive_format(archive_name, ARCHIVE_FORMATS)

	if not format_config then
		return nil
	end

	-- Handle special cases
	if format_config.special_handling == "convert_to_tar" then
		local tar_name = archive_name:gsub("%.lzop$", ".tar.lzop")
		local tool = find_available_tool(format_config.compression_tools)
		if tool then
			return build_tar_command_with_compression(tar_name, files, tool)
		end
		return nil
	end

	-- Single-file compression
	if format_config.single_file then
		local tool = find_available_tool(format_config.compression_tools)
		if tool then
			return build_single_file_compression_command(archive_name, files, tool)
		end
		return nil
	end

	-- TAR-based compression
	if format_config.requires_tar then
		local compression_tool = find_available_tool(format_config.compression_tools)
		if compression_tool and is_command_available("tar") then
			return build_tar_command_with_compression(archive_name, files, compression_tool)
		elseif is_command_available("tar") and format_config.tar_flag then
			local flag = format_config.tar_flag
			if flag == "--zstd" and format_config.fallback_flag then
				return { "tar", flag, format_config.fallback_flag, archive_name, unpack(files) }
			else
				return { "tar", flag, archive_name, unpack(files) }
			end
		end
		return nil
	end

	-- Standard archive formats
	local tool = find_available_tool(format_config.tools)
	if tool and format_config.compress_args then
		local cmd = { tool }
		for _, arg in ipairs(format_config.compress_args) do
			table.insert(cmd, arg)
		end
		table.insert(cmd, archive_name)
		for _, file in ipairs(files) do
			table.insert(cmd, file)
		end
		return cmd
	end

	-- Try fallback tools
	if format_config.fallback_tools then
		local fallback_tool = find_available_tool(format_config.fallback_tools)
		if fallback_tool then
			return { fallback_tool, "a", archive_name, unpack(files) }
		end
	end

	return nil
end

local function get_fallback_compression_command(archive_name, files)
	local fallback_commands = {
		{ tool = "zip", args = { "-r", archive_name .. ".zip" } },
		{ tool = "7z", args = { "a", archive_name .. ".zip" } },
		{ tool = "7za", args = { "a", archive_name .. ".zip" } },
	}

	for _, fallback in ipairs(fallback_commands) do
		if is_command_available(fallback.tool) then
			local cmd = { fallback.tool }
			for _, arg in ipairs(fallback.args) do
				table.insert(cmd, arg)
			end
			for _, file in ipairs(files) do
				table.insert(cmd, file)
			end
			return cmd
		end
	end

	return nil
end

-- Archive extraction
local function is_compressed_tar_archive(file_path)
	return file_path:lower():match("%.tar%.")
end

local function build_single_file_decompression_command(archive_path)
	local _, format_config = find_archive_format(archive_path, EXTRACTION_FORMATS.ambiguous_compressed)
	if not format_config then
		return nil
	end

	local ext = get_file_extension(archive_path)
	for pattern, tools in pairs(format_config.single_file_tools) do
		if ext:match(pattern) then
			local tool = find_available_tool(tools)
			if tool then
				return { tool, "-dc", archive_path }
			end
		end
	end

	return nil
end

local function build_extraction_command(archive_path, output_dir)
	local format_name, format_config = find_archive_format(archive_path, EXTRACTION_FORMATS)

	if not format_config then
		-- Try fallback extraction
		local fallback_tools = { "7z", "7za", "unzip" }
		local tool = find_available_tool(fallback_tools)
		if tool then
			local cmd = { tool, "x", archive_path }
			if output_dir then
				if tool == "unzip" then
					table.insert(cmd, "-d")
					table.insert(cmd, output_dir)
				else
					table.insert(cmd, "-o" .. output_dir)
				end
			end
			return cmd
		end
		return nil
	end

	-- Handle ambiguous compressed files
	if format_config.check_tar then
		if is_compressed_tar_archive(archive_path) then
			-- Treat as compressed tar
			if is_command_available("tar") then
				local cmd = { "tar", "-xf", archive_path }
				if output_dir then
					table.insert(cmd, "-C")
					table.insert(cmd, output_dir)
				end
				return cmd
			end
		else
			-- Treat as single-file compression
			return build_single_file_decompression_command(archive_path)
		end
		return nil
	end

	-- Handle RAR special case
	if format_name == "rar" then
		local tool = find_available_tool(format_config.tools)
		if tool then
			local cmd = { tool }
			for _, arg in ipairs(format_config.args) do
				table.insert(cmd, arg)
			end
			table.insert(cmd, archive_path)
			if output_dir then
				table.insert(cmd, output_dir)
			end
			return cmd
		end
	end

	-- Standard extraction
	local tool = format_config.command or find_available_tool(format_config.tools)
	if tool and is_command_available(tool) then
		local cmd = { tool }
		if format_config.args then
			for _, arg in ipairs(format_config.args) do
				table.insert(cmd, arg)
			end
		end
		table.insert(cmd, archive_path)

		if output_dir and format_config.output_flag then
			if format_config.output_flag == "-o" then
				table.insert(cmd, "-o" .. output_dir)
			elseif format_config.output_flag == "--output=" then
				table.insert(cmd, "--output=" .. output_dir)
			else
				table.insert(cmd, format_config.output_flag)
				table.insert(cmd, output_dir)
			end
		end

		return cmd
	end

	-- Try fallback
	if format_config.fallback then
		local fallback = format_config.fallback
		if is_command_available(fallback.tool) then
			local cmd = { fallback.tool }
			for _, arg in ipairs(fallback.args) do
				table.insert(cmd, arg)
			end
			table.insert(cmd, archive_path)

			if output_dir and fallback.output_flag then
				if fallback.output_flag == "-o" then
					table.insert(cmd, "-o" .. output_dir)
				else
					table.insert(cmd, fallback.output_flag)
					table.insert(cmd, output_dir)
				end
			end

			return cmd
		end
	end

	return nil
end

-- Core operations
local function execute_command_safely(cmd)
	if not cmd or #cmd == 0 then
		return false, "No command to execute"
	end

	local args = {}
	for i = 2, #cmd do
		args[#args + 1] = cmd[i]
	end

	local output, err = Command(cmd[1]):arg(args):output()

	if output and output.status.success then
		return true, nil
	else
		local error_msg = "Unknown error"
		if output and output.stderr and output.stderr ~= "" then
			error_msg = output.stderr
		elseif err then
			error_msg = tostring(err)
		end
		return false, error_msg
	end
end

local function validate_files(files)
	if not files or #files == 0 then
		return false, "No files selected"
	end
	return true, nil
end

local function validate_archive_name(archive_name)
	if not archive_name or archive_name == "" then
		return false, "Archive name cannot be empty"
	end
	return true, nil
end

local function compress_selected_files(archive_name, files)
	local is_valid, error_msg = validate_files(files)
	if not is_valid then
		ya.notify({
			title = "Archives",
			content = error_msg,
			level = "error",
			timeout = 5,
		})
		return
	end

	is_valid, error_msg = validate_archive_name(archive_name)
	if not is_valid then
		ya.notify({
			title = "Archives",
			content = error_msg,
			level = "error",
			timeout = 5,
		})
		return
	end

	local current_dir = get_current_directory()
	local relative_files = convert_to_relative_paths(files, current_dir)

	local cmd = build_compression_command(archive_name, relative_files)
	if not cmd then
		cmd = get_fallback_compression_command(archive_name, relative_files)
	end

	if not cmd then
		ya.notify({
			title = "Archives",
			content = "No suitable compression tool found",
			level = "error",
			timeout = 5,
		})
		return
	end

	local success, err = execute_command_safely(cmd)

	if success then
		ya.notify({
			title = "Archives",
			content = "Compressed successfully",
			timeout = 4,
		})
		ya.manager_emit("refresh", {})
	else
		ya.notify({
			title = "Archives",
			content = "Compression failed: " .. err,
			level = "error",
			timeout = 5,
		})
	end
end

local function extract_selected_files(files, output_dir)
	local is_valid, error_msg = validate_files(files)
	if not is_valid then
		ya.notify({
			title = "Archives",
			content = error_msg,
			level = "error",
			timeout = 5,
		})
		return
	end

	for _, file in ipairs(files) do
		local cmd = build_extraction_command(file, output_dir)
		if not cmd then
			ya.notify({
				title = "Archives",
				content = "Unsupported archive format: " .. file:match("[^/]+$"),
				level = "warn",
				timeout = 5,
			})
			goto continue
		end

		local success, err = execute_command_safely(cmd)

		if success then
			ya.notify({
				title = "Archives",
				content = "Extracted successfully",
				timeout = 5,
			})
		else
			ya.notify({
				title = "Archives",
				content = "Extraction failed: " .. err,
				level = "error",
				timeout = 5,
			})
		end

		::continue::
	end
	ya.manager_emit("refresh", {})
end

local function show_usage()
	ya.notify({
		title = "Archives",
		content = "Usage:\n  compress [archive_name]\n  extract [output_dir]",
		level = "info",
		timeout = 5,
	})
end

local function handle_compress_command(args)
	local files = get_selected_files()

	if #files == 0 then
		ya.notify({
			title = "Archives",
			content = "No files selected",
			level = "error",
			timeout = 5,
		})
		return
	end

	local archive_name = args[2]

	if archive_name then
		compress_selected_files(archive_name, files)
	else
		local current_dir = get_current_directory()
		local current_dir_name = current_dir:match("[^/]+$") or "current directory"

		local value, event = ya.input({
			title = "Compress to archive (in " .. current_dir_name .. "):",
			position = { "center", w = 50 },
		})

		if event == 1 and value and value ~= "" then
			compress_selected_files(value, files)
		end
	end
end

local function handle_extract_command(args)
	local files = get_selected_files()
	local output_dir = args[2]
	extract_selected_files(files, output_dir)
end

-- Plugin entry point
local plugin = {
	entry = function(self, job)
		local args = job.args
		local command = args[1]

		if command == "compress" then
			handle_compress_command(args)
		elseif command == "extract" then
			handle_extract_command(args)
		else
			show_usage()
		end
	end,
}

return plugin
