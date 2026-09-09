#!/usr/bin/env bash

# ==============================================================================
# FZF Preview Handler Script
# Inspired by Yazi File Manager, but enhanced for terminal search integration.
# Handled Formats: Code/Text, Directories, Archives, PDF, JSON, Images, Audio/Video,
#                  SQL/SQLite, Office Documents, HTML/Markdown, and Binary metadata.
# ==============================================================================

# Add common Homebrew and MacPorts paths for macOS compatibility
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

FILE="$1"
LINE="$2"

if [ -z "$FILE" ]; then
	echo "Error: No file specified"
	exit 1
fi

if [ ! -e "$FILE" ]; then
	echo "Error: File or directory not found: $FILE"
	exit 1
fi

# Get lowercase file extension (using zero-fork bash 4+ builtins if possible)
EXT="${FILE##*.}"
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
	EXT="${EXT,,}"
else
	EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
fi

# Lazy MIME type resolution helper to avoid unnecessary 'file' forks
MIME=""
get_mime() {
	[ -n "$MIME" ] && return
	MIME=$(file --mime-type -b -- "$FILE" 2>/dev/null)
}

# ------------------------------------------------------------------------------
# 1. Directories
# ------------------------------------------------------------------------------
if [ -d "$FILE" ]; then
	echo "📁 Directory: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v eza >/dev/null 2>&1; then
		eza -la --color=always --icons --group-directories-first "$FILE"
	elif command -v exa >/dev/null 2>&1; then
		exa -la --color=always --group-directories-first "$FILE"
	else
		ls -la "$FILE"
	fi
	exit 0
fi

# Helper for image/graphics previewing (centered & scaled)
preview_image() {
	local cols="${FZF_PREVIEW_COLUMNS:-80}"
	local lines="${FZF_PREVIEW_LINES:-40}"
	local left="${FZF_PREVIEW_LEFT:-0}"
	local top="${FZF_PREVIEW_TOP:-0}"

	# Get image dimensions in pixels
	local img_w img_h
	if command -v magick >/dev/null 2>&1; then
		read -r img_w img_h < <(magick identify -format "%w %h" "$1" 2>/dev/null)
	elif command -v file >/dev/null 2>&1; then
		local file_info
		file_info=$(file -b -- "$1" 2>/dev/null)
		if [[ "$file_info" =~ ([0-9]+)\ *x\ *([0-9]+) ]]; then
			img_w="${BASH_REMATCH[1]}"
			img_h="${BASH_REMATCH[2]}"
		fi
	fi

	# Fallback to default 4:3 aspect ratio if dimensions detection fails
	if [ -z "$img_w" ] || [ -z "$img_h" ] || [ "$img_w" -eq 0 ] || [ "$img_h" -eq 0 ]; then
		img_w=800
		img_h=600
	fi

	# Character cell aspect ratio (width/height) is roughly 0.5 (typical font is 1:2)
	# Scale image to fit the preview pane while keeping aspect ratio
	local h_cells=$((cols * img_h / (2 * img_w)))
	local w_cells=$cols
	local padding_x=0
	local padding_y=0

	if [ "$h_cells" -le "$lines" ]; then
		# Fits by width
		padding_y=$(((lines - h_cells) / 2))
	else
		# Fits by height instead
		h_cells=$lines
		w_cells=$((lines * 2 * img_w / img_h))
		if [ "$w_cells" -gt "$cols" ]; then
			w_cells=$cols
		fi
		padding_x=$(((cols - w_cells) / 2))
	fi

	[ "$padding_x" -lt 0 ] && padding_x=0
	[ "$padding_y" -lt 0 ] && padding_y=0

	# Calculate absolute coordinates for high-res terminal graphics
	local offset_x=$((left + padding_x))
	local offset_y=$((top + padding_y))

	# 1. Kitty Terminal native image protocol (with tmux-friendly unicode-placeholder and memory transfer)
	if [ -n "$KITTY_WINDOW_ID" ] || [ "$TERM" = "xterm-kitty" ] || [ "$TERMINAL" = "kitty" ]; then
		if [ -n "$FZF_PREVIEW_LEFT" ] && [ -n "$FZF_PREVIEW_TOP" ]; then
			kitty +kitten icat --clear --transfer-mode=memory --stdin=no --unicode-placeholder --place "${w_cells}x${h_cells}@${offset_x}x${offset_y}" --scale-up "$1" 2>/dev/null && exit 0
		else
			kitty +kitten icat --clear --transfer-mode=memory --stdin=no --unicode-placeholder --place "${cols}x${lines}@0x0" --align center --scale-up "$1" 2>/dev/null && exit 0
		fi
	fi

	# If inside tmux (and not using Kitty), force text-safe symbols to prevent raw placeholder character pollution
	if [ -n "$TMUX" ]; then
		# 2. Chafa in symbols mode (clean, high-density, centered)
		if command -v chafa >/dev/null 2>&1; then
			chafa --size="${cols}x${lines}" --view-size="${cols}x${lines}" --symbols=block+border+solid+wedge+sextant+space --align mid,mid --format=symbols "$1" && exit 0
		fi
		# 3. Rust Viu
		if command -v viu >/dev/null 2>&1; then
			viu -w "$cols" -h "$lines" "$1" && exit 0
		fi
	else
		# Not inside tmux: native high-resolution protocols are fully supported
		# 2. Chafa (Unicode/ANSI character graphics with alignment and FZF window constraints)
		if command -v chafa >/dev/null 2>&1; then
			chafa --size="${cols}x${lines}" --view-size="${cols}x${lines}" --symbols=block+border+solid+wedge+sextant+space --align mid,mid "$1" && exit 0
		fi
		# 3. Rust Viu (Terminal Image Viewer)
		if command -v viu >/dev/null 2>&1; then
			viu -w "$cols" -h "$lines" "$1" && exit 0
		fi
	fi

	# 4. Fallback: Exif/Metadata extraction
	echo "🖼️ Image Metadata for: ${1##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v exiftool >/dev/null 2>&1; then
		exiftool "$1"
	else
		file "$1"
	fi
}

# Helper to render documents (PDF, Word, Excel, etc.) as images and preview them
preview_document() {
	local doc_file="$1"
	local base
	base="${doc_file##*/}"
	local tmp_dir
	tmp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/fzf-doc-$$")
	mkdir -p "$tmp_dir"

	# 1. For PDF files: Use pdftoppm (from Poppler) as the primary high-resolution crisp renderer
	if [[ "$EXT" == "pdf" ]] && command -v pdftoppm >/dev/null 2>&1; then
		pdftoppm -png -r 200 -f 1 -l 1 "$doc_file" "$tmp_dir/page" >/dev/null 2>&1
		if [ -f "$tmp_dir/page-1.png" ]; then
			preview_image "$tmp_dir/page-1.png"
			rm -rf "$tmp_dir"
			exit 0
		fi
	fi

	# 2. For Word files (.docx, .doc): Try converting to PDF via LibreOffice, then rendering cleanly via pdftoppm
	if [[ "$EXT" == "docx" || "$EXT" == "doc" ]]; then
		if command -v soffice >/dev/null 2>&1 || command -v libreoffice >/dev/null 2>&1 || [ -f "/Applications/LibreOffice.app/Contents/MacOS/soffice" ]; then
			local soffice_cmd="soffice"
			if command -v libreoffice >/dev/null 2>&1; then
				soffice_cmd="libreoffice"
			elif [ -f "/Applications/LibreOffice.app/Contents/MacOS/soffice" ]; then
				soffice_cmd="/Applications/LibreOffice.app/Contents/MacOS/soffice"
			fi

			# Convert Word to PDF first
			$soffice_cmd --headless --convert-to pdf --outdir "$tmp_dir" "$doc_file" >/dev/null 2>&1
			local pdf_file
			pdf_file=$(find "$tmp_dir" -name "*.pdf" -print -quit)
			if [ -n "$pdf_file" ] && [ -f "$pdf_file" ]; then
				if command -v pdftoppm >/dev/null 2>&1; then
					pdftoppm -png -r 200 -f 1 -l 1 "$pdf_file" "$tmp_dir/page" >/dev/null 2>&1
					if [ -f "$tmp_dir/page-1.png" ]; then
						preview_image "$tmp_dir/page-1.png"
						rm -rf "$tmp_dir"
						exit 0
					fi
				fi
			fi
		fi
	fi

	# 3. macOS QuickLook (qlmanage) - fallback for PDF/Word if primary tools failed, or primary for other docs (pages, key, numbers, xlsx, pptx)
	if command -v qlmanage >/dev/null 2>&1; then
		qlmanage -t -s 1500 -o "$tmp_dir" "$doc_file" >/dev/null 2>&1
		local generated_png="$tmp_dir/$base.png"
		if [ -f "$generated_png" ]; then
			preview_image "$generated_png"
			rm -rf "$tmp_dir"
			exit 0
		fi
	fi

	rm -rf "$tmp_dir"

	# 4. Fallbacks (NO text extraction as requested)
	if [[ "$EXT" == "xlsx" || "$EXT" == "xls" ]]; then
		echo "📊 Excel Spreadsheet: $base"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		if command -v xlsx2csv >/dev/null 2>&1; then
			xlsx2csv "$doc_file" | head -n 150
			exit 0
		fi
	fi

	echo "📄 Document: $base"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if [[ "$EXT" == "pdf" ]] && command -v pdfinfo >/dev/null 2>&1; then
		pdfinfo "$doc_file"
	elif command -v exiftool >/dev/null 2>&1; then
		exiftool "$doc_file"
	else
		file "$doc_file"
	fi
	exit 0
}

# ------------------------------------------------------------------------------
# 2. Archives
# ------------------------------------------------------------------------------
case "$EXT" in
zip | jar | war | ipa | apk)
	echo "📦 Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v unzip >/dev/null 2>&1; then
		unzip -l "$FILE" | head -n 150
		exit 0
	fi
	;;
tar)
	echo "📦 Tar Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -tf "$FILE" | head -n 150
	exit 0
	;;
tgz | tar.gz)
	echo "📦 Compressed Tar Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -ztf "$FILE" | head -n 150
	exit 0
	;;
tbz2 | tar.bz2)
	echo "📦 Compressed Tar Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -jtf "$FILE" | head -n 150
	exit 0
	;;
txz | tar.xz)
	echo "📦 Compressed Tar Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -Jtf "$FILE" | head -n 150
	exit 0
	;;
7z)
	echo "📦 7-Zip Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v 7z >/dev/null 2>&1; then
		7z l "$FILE" | head -n 150
		exit 0
	elif command -v 7za >/dev/null 2>&1; then
		7za l "$FILE" | head -n 150
		exit 0
	fi
	;;
rar)
	echo "📦 RAR Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v unrar >/dev/null 2>&1; then
		unrar l "$FILE" | head -n 150
		exit 0
	elif command -v 7z >/dev/null 2>&1; then
		7z l "$FILE" | head -n 150
		exit 0
	fi
	;;
deb)
	echo "📦 Debian Package Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v dpkg >/dev/null 2>&1; then
		dpkg -c "$FILE" | head -n 150
		exit 0
	else
		ar -t "$FILE" | head -n 150
		exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 3. Documents, Structured Data & Rich Content
# ------------------------------------------------------------------------------
case "$EXT" in
pdf | docx | doc | xlsx | xls | pptx | ppt | pages | key | numbers)
	preview_document "$FILE"
	;;
json)
	if command -v jq >/dev/null 2>&1; then
		jq -C . "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
md | markdown)
	if command -v glow >/dev/null 2>&1; then
		glow -p -w 80 -s dark "$FILE" && exit 0
	elif command -v mdcat >/dev/null 2>&1; then
		mdcat "$FILE" && exit 0
	elif command -v rich >/dev/null 2>&1; then
		rich "$FILE" --markdown --force-terminal && exit 0
	elif command -v bat >/dev/null 2>&1; then
		bat --map-syntax=.ignore:Git --color=always --style=numbers --theme=Dracula "$FILE" && exit 0
	else
		cat "$FILE" | head -n 250 && exit 0
	fi
	;;
html | htm)
	if command -v w3m >/dev/null 2>&1; then
		w3m -dump "$FILE" | head -n 150 && exit 0
	elif command -v lynx >/dev/null 2>&1; then
		lynx -dump "$FILE" | head -n 150 && exit 0
	fi
	;;
sqlite | sqlite3 | db)
	if command -v sqlite3 >/dev/null 2>&1; then
		echo "🗄️ SQLite Database: $FILE"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "=== TABLES ==="
		sqlite3 "$FILE" .tables
		echo ""
		echo "=== SCHEMA ==="
		sqlite3 "$FILE" .schema | head -n 100
		exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 4. MIME-type Fallback Matchers
# ------------------------------------------------------------------------------
get_mime
case "$MIME" in
image/*)
	preview_image "$FILE"
	exit 0
	;;
audio/* | video/*)
	echo "🎵 Media File Info: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v mediainfo >/dev/null 2>&1; then
		mediainfo "$FILE"
		exit 0
	elif command -v ffprobe >/dev/null 2>&1; then
		ffprobe -hide_banner "$FILE" 2>&1
		exit 0
	fi
	;;
application/pdf | *msword* | *wordprocessingml* | *ms-excel* | *spreadsheetml* | *ms-powerpoint* | *presentationml* | *vnd.oasis.opendocument*)
	preview_document "$FILE"
	;;
text/html)
	if command -v w3m >/dev/null 2>&1; then
		w3m -dump "$FILE" | head -n 150 && exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 5. Executable Binary check (help output)
# ------------------------------------------------------------------------------
get_mime
if [ -x "$FILE" ] && [ ! -d "$FILE" ] && [[ "$MIME" != text/* && "$MIME" != *"script"* && "$MIME" != *"python"* && "$MIME" != *"perl"* && "$MIME" != *"ruby"* && "$MIME" != *"php"* && "$MIME" != *"json"* ]]; then
	echo "⚙️ Executable Command: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	file "$FILE"
	echo ""
	echo "=== HELP OUTPUT ==="
	"$FILE" --help 2>&1 | head -n 100 || "$FILE" -h 2>&1 | head -n 100 || echo "No direct help output available."
	exit 0
fi

# ------------------------------------------------------------------------------
# 6. Raw Binary Fallback
# ------------------------------------------------------------------------------
get_mime
if [[ "$MIME" == *"octet-stream"* || "$MIME" == *"binary"* ]]; then
	echo "⚙️ Binary Executable / Object: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v exiftool >/dev/null 2>&1; then
		exiftool "$FILE"
	else
		file "$FILE"
	fi
	exit 0
fi

# ------------------------------------------------------------------------------
# 6. Default Text Highlight (using bat / fallback cat)
# ------------------------------------------------------------------------------
if command -v bat >/dev/null 2>&1; then
	if [ -n "$LINE" ]; then
		bat --map-syntax=.ignore:Git --color=always --style=numbers --theme=Dracula --highlight-line="$LINE" "$FILE"
	else
		bat --map-syntax=.ignore:Git --color=always --style=numbers --theme=Dracula "$FILE"
	fi
else
	cat "$FILE" | head -n 250
fi
