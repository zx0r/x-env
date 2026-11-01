#!/usr/bin/env bash

# ==============================================================================
# FZF Unified Multi-Format High-Performance Preview Handler
# Architecture: Zero-crash fallback cascades, Apple Silicon & macOS native optimizations,
#               terminal graphics protocols (Kitty/iTerm2/Chafa/Viu), documents (PDF/Office),
#               structured data, media metadata, Mach-O binaries, archives, and syntax trees.
# ==============================================================================

# Ensure standard Darwin and Homebrew binary search paths
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Enable fast, safe string operations
FILE="$1"
LINE="${2:-}"
COL="${3:-}"

# Parse ripgrep/grep colon-separated strings if passed as a single argument (e.g. "path:line:col:match")
if [ -z "$LINE" ] && [[ "$FILE" =~ ^([^:]+):([0-9]+)(:([0-9]+))?:?.*$ ]]; then
	FILE="${BASH_REMATCH[1]}"
	LINE="${BASH_REMATCH[2]}"
	COL="${BASH_REMATCH[4]}"
fi

# Sanitize surrounding quotes or trailing colons
FILE="${FILE%\'}"
FILE="${FILE#\'}"
FILE="${FILE%\"}"
FILE="${FILE#\"}"
FILE="${FILE%:}"

# Expand tilde if present
if [[ "$FILE" == ~* ]]; then
	FILE="${HOME}${FILE#\~}"
fi

# Handle empty target
if [ -z "$FILE" ]; then
	echo "Error: No target specified for preview"
	exit 1
fi

# Handle Git object/commit hashes if not a filesystem path
if [ ! -e "$FILE" ]; then
	if git rev-parse --quiet --verify "$FILE" >/dev/null 2>&1; then
		echo "🌿 Git Commit Object: $FILE"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		git show --color=always --stat --patch "$FILE" 2>/dev/null | head -n 250
		exit 0
	fi
	echo "Target not found: $FILE"
	exit 0
fi

# Extract lowercase file extension
EXT="${FILE##*.}"
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
	EXT="${EXT,,}"
else
	EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
fi

# Lazy MIME type detector to avoid subshell forks unless strictly needed
MIME=""
get_mime() {
	[ -n "$MIME" ] && return
	MIME=$(file --mime-type -b -- "$FILE" 2>/dev/null)
}

# ------------------------------------------------------------------------------
# 1. Directories & Trees
# ------------------------------------------------------------------------------
if [ -d "$FILE" ]; then
	echo "📁 Directory: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	# Summary header: entry count and disk usage
	local_count=$(find "$FILE" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
	echo "Entries: $((local_count > 0 ? local_count - 1 : 0)) item(s)"
	echo ""
	if command -v eza >/dev/null 2>&1; then
		eza --tree --level=2 --icons --color=always --group-directories-first "$FILE" 2>/dev/null | head -n 120
	elif command -v exa >/dev/null 2>&1; then
		exa --tree --level=2 --color=always --group-directories-first "$FILE" 2>/dev/null | head -n 120
	elif command -v tree >/dev/null 2>&1; then
		tree -C -L 2 "$FILE" 2>/dev/null | head -n 120
	else
		ls -la "$FILE" 2>/dev/null | head -n 120
	fi
	exit 0
fi

# ------------------------------------------------------------------------------
# Helper: Terminal Graphics Renderer (Kitty, iTerm2/Ghostty, Chafa, Viu)
# ------------------------------------------------------------------------------
preview_image() {
	local img="$1"
	[ ! -f "$img" ] && return 1

	local cols="${FZF_PREVIEW_COLUMNS:-80}"
	local lines="${FZF_PREVIEW_LINES:-40}"
	local left="${FZF_PREVIEW_LEFT:-0}"
	local top="${FZF_PREVIEW_TOP:-0}"

	# Query image dimensions in pixels via macOS native sips or ImageMagick
	local img_w=0 img_h=0
	if command -v sips >/dev/null 2>&1; then
		read -r img_w img_h < <(sips -g pixelWidth -g pixelHeight "$img" 2>/dev/null | awk '/pixelWidth:/{w=$2} /pixelHeight:/{h=$2} END{print w, h}')
	elif command -v magick >/dev/null 2>&1; then
		read -r img_w img_h < <(magick identify -format "%w %h" "$img" 2>/dev/null)
	fi

	# Fallback aspect ratio if dimension detection failed
	if [ -z "$img_w" ] || [ -z "$img_h" ] || [ "$img_w" -eq 0 ] || [ "$img_h" -eq 0 ]; then
		img_w=800
		img_h=600
	fi

	# Character cell aspect ratio is roughly 0.5 (height = 2x width in terminal fonts)
	local h_cells=$((cols * img_h / (2 * img_w)))
	local w_cells=$cols
	local padding_x=0
	local padding_y=0

	if [ "$h_cells" -le "$lines" ]; then
		padding_y=$(((lines - h_cells) / 2))
	else
		h_cells=$lines
		w_cells=$((lines * 2 * img_w / img_h))
		[ "$w_cells" -gt "$cols" ] && w_cells=$cols
		padding_x=$(((cols - w_cells) / 2))
	fi

	[ "$padding_x" -lt 0 ] && padding_x=0
	[ "$padding_y" -lt 0 ] && padding_y=0

	local offset_x=$((left + padding_x))
	local offset_y=$((top + padding_y))

	# 1. Kitty Terminal native image protocol
	if [ -n "$KITTY_WINDOW_ID" ] || [ "$TERM" = "xterm-kitty" ] || [ "$TERMINAL" = "kitty" ]; then
		if [ -n "$FZF_PREVIEW_LEFT" ] && [ -n "$FZF_PREVIEW_TOP" ]; then
			kitty +kitten icat --clear --transfer-mode=memory --stdin=no --unicode-placeholder \
				--place "${w_cells}x${h_cells}@${offset_x}x${offset_y}" --scale-up "$img" 2>/dev/null && exit 0
		else
			kitty +kitten icat --clear --transfer-mode=memory --stdin=no --unicode-placeholder \
				--place "${cols}x${lines}@0x0" --align center --scale-up "$img" 2>/dev/null && exit 0
		fi
	fi

	# 2. iTerm2 / Ghostty / WezTerm inline image protocol
	if [ -z "$TMUX" ] && { [ "$TERM_PROGRAM" = "iTerm.app" ] || [ "$TERM_PROGRAM" = "ghostty" ] || [ "$TERM_PROGRAM" = "WezTerm" ] || [ -n "$ITERM_SESSION_ID" ]; }; then
		if command -v chafa >/dev/null 2>&1; then
			chafa --format=iterm --size="${cols}x${lines}" --align mid,mid "$img" 2>/dev/null && exit 0
		fi
	fi

	# 3. Inside TMUX: force symbol characters to prevent protocol corruption
	if [ -n "$TMUX" ]; then
		if command -v chafa >/dev/null 2>&1; then
			chafa --size="${cols}x${lines}" --view-size="${cols}x${lines}" \
				--symbols=block+border+solid+wedge+sextant+space --align mid,mid --format=symbols "$img" 2>/dev/null && exit 0
		fi
		if command -v viu >/dev/null 2>&1; then
			viu -w "$cols" -h "$lines" "$img" 2>/dev/null && exit 0
		fi
	else
		# 4. Standard terminal high-resolution Chafa / Viu
		if command -v chafa >/dev/null 2>&1; then
			chafa --size="${cols}x${lines}" --view-size="${cols}x${lines}" \
				--symbols=block+border+solid+wedge+sextant+space --align mid,mid "$img" 2>/dev/null && exit 0
		fi
		if command -v viu >/dev/null 2>&1; then
			viu -w "$cols" -h "$lines" "$img" 2>/dev/null && exit 0
		fi
	fi

	# 5. Fallback: Native macOS image metadata inspector
	echo "🖼️ Image Metadata: ${img##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v sips >/dev/null 2>&1; then
		sips -g all "$img" 2>/dev/null | grep -E "pixelWidth|pixelHeight|format|space|profile|hasAlpha"
	elif command -v exiftool >/dev/null 2>&1; then
		exiftool "$img" 2>/dev/null | head -n 40
	else
		file "$img"
	fi
	exit 0
}

# ------------------------------------------------------------------------------
# Helper: Document Renderer (PDF, Word, Excel, Pages, Keynote)
# ------------------------------------------------------------------------------
preview_document() {
	local doc="$1"
	local base="${doc##*/}"
	local tmp_dir
	tmp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/fzf-preview-$$")
	mkdir -p "$tmp_dir"

	# PDF: High-resolution rasterization via Poppler pdftoppm
	if [[ "$EXT" == "pdf" ]] && command -v pdftoppm >/dev/null 2>&1; then
		pdftoppm -png -r 150 -f 1 -l 1 "$doc" "$tmp_dir/page" >/dev/null 2>&1
		if [ -f "$tmp_dir/page-1.png" ]; then
			preview_image "$tmp_dir/page-1.png"
			rm -rf "$tmp_dir"
			exit 0
		fi
	fi

	# Word, Excel, PowerPoint, RTF, Pages, Keynote via macOS QuickLook (qlmanage)
	if command -v qlmanage >/dev/null 2>&1; then
		qlmanage -t -s 1500 -o "$tmp_dir" "$doc" >/dev/null 2>&1
		local generated_png="$tmp_dir/$base.png"
		if [ -f "$generated_png" ]; then
			preview_image "$generated_png"
			rm -rf "$tmp_dir"
			exit 0
		fi
	fi

	rm -rf "$tmp_dir"

	# Text-based Document Fallbacks
	echo "📄 Document: $base"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	# PDF text extraction fallback
	if [[ "$EXT" == "pdf" ]]; then
		if command -v pdfinfo >/dev/null 2>&1; then
			pdfinfo "$doc" 2>/dev/null
			echo ""
		fi
		if command -v pdftotext >/dev/null 2>&1; then
			echo "=== EXTRACTED TEXT PREVIEW ==="
			pdftotext -layout "$doc" - 2>/dev/null | head -n 120
			exit 0
		fi
	fi

	# Word / RTF text extraction fallback via macOS native textutil
	if [[ "$EXT" == "docx" || "$EXT" == "doc" || "$EXT" == "rtf" || "$EXT" == "odt" ]]; then
		if command -v textutil >/dev/null 2>&1; then
			echo "=== NATIVE TEXTUTIL EXTRACTION ==="
			textutil -convert txt -stdout "$doc" 2>/dev/null | head -n 150
			exit 0
		fi
		if command -v docx2txt >/dev/null 2>&1; then
			docx2txt "$doc" - 2>/dev/null | head -n 150
			exit 0
		fi
	fi

	# Spreadsheet fallback
	if [[ "$EXT" == "xlsx" || "$EXT" == "xls" || "$EXT" == "csv" ]]; then
		if command -v xlsx2csv >/dev/null 2>&1; then
			xlsx2csv "$doc" 2>/dev/null | head -n 80 | column -s, -t | head -n 80
			exit 0
		fi
	fi

	# General Metadata Fallback
	if command -v mdls >/dev/null 2>&1; then
		mdls "$doc" 2>/dev/null | head -n 40
	elif command -v exiftool >/dev/null 2>&1; then
		exiftool "$doc" 2>/dev/null | head -n 40
	else
		file "$doc"
	fi
	exit 0
}

# ------------------------------------------------------------------------------
# 2. Archives & Package Bundles
# ------------------------------------------------------------------------------
case "$EXT" in
zip | jar | war | ear | ipa | apk)
	echo "📦 Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v ouch >/dev/null 2>&1; then
		ouch l "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	if command -v unzip >/dev/null 2>&1; then
		unzip -l "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
tar)
	echo "📦 Tar Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -tf "$FILE" 2>/dev/null | head -n 150 && exit 0
	;;
tgz | tar.gz)
	echo "📦 Gzip Compressed Tar Archive: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -ztf "$FILE" 2>/dev/null | head -n 150 && exit 0
	;;
tbz2 | tar.bz2)
	echo "📦 Bzip2 Compressed Tar Archive: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -jtf "$FILE" 2>/dev/null | head -n 150 && exit 0
	;;
txz | tar.xz)
	echo "📦 XZ Compressed Tar Archive: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar -Jtf "$FILE" 2>/dev/null | head -n 150 && exit 0
	;;
tar.zst | tzst)
	echo "📦 Zstandard Compressed Tar Archive: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	tar --zstd -tf "$FILE" 2>/dev/null | head -n 150 && exit 0
	;;
7z)
	echo "📦 7-Zip Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v 7z >/dev/null 2>&1; then
		7z l "$FILE" 2>/dev/null | head -n 150 && exit 0
	elif command -v 7za >/dev/null 2>&1; then
		7za l "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
rar)
	echo "📦 RAR Archive Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v unrar >/dev/null 2>&1; then
		unrar l "$FILE" 2>/dev/null | head -n 150 && exit 0
	elif command -v 7z >/dev/null 2>&1; then
		7z l "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
dmg)
	echo "💿 Apple Disk Image (DMG): $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v hdiutil >/dev/null 2>&1; then
		hdiutil imageinfo "$FILE" 2>/dev/null | head -n 100 && exit 0
	fi
	;;
pkg)
	echo "📦 Apple Installer Package (PKG): $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v xar >/dev/null 2>&1; then
		xar -tf "$FILE" 2>/dev/null | head -n 150 && exit 0
	elif command -v pkgutil >/dev/null 2>&1; then
		pkgutil --payload-files "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
deb)
	echo "📦 Debian Package Contents: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v dpkg >/dev/null 2>&1; then
		dpkg -c "$FILE" 2>/dev/null | head -n 150 && exit 0
	else
		ar -t "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
zst)
	echo "📦 Zstandard Compressed Stream: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v zstd >/dev/null 2>&1; then
		zstd -l "$FILE" 2>/dev/null && exit 0
	fi
	;;
gz)
	echo "📦 Gzip Compressed File: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	gzip -l "$FILE" 2>/dev/null && exit 0
	;;
esac

# ------------------------------------------------------------------------------
# 3. Documents, Office, Spreadsheets & eBooks
# ------------------------------------------------------------------------------
case "$EXT" in
pdf | docx | doc | xlsx | xls | pptx | ppt | pages | key | numbers | odt | ods | odp | rtf)
	preview_document "$FILE"
	;;
epub | mobi | azw3)
	echo "📚 eBook: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v pandoc >/dev/null 2>&1; then
		pandoc -t plain "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	if command -v unzip >/dev/null 2>&1; then
		unzip -l "$FILE" 2>/dev/null | head -n 80 && exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 4. Images & Graphics Formats
# ------------------------------------------------------------------------------
case "$EXT" in
png | jpg | jpeg | webp | gif | avif | bmp | tiff | tif | ico | heic | heif | icns)
	preview_image "$FILE"
	;;
svg)
	# SVG vector rasterization thumbnail or XML code
	tmp_svg_png="/tmp/fzf-svg-$$.png"
	if command -v rsvg-convert >/dev/null 2>&1; then
		rsvg-convert -w 1200 "$FILE" -o "$tmp_svg_png" 2>/dev/null
	elif command -v magick >/dev/null 2>&1; then
		magick "$FILE" "$tmp_svg_png" 2>/dev/null
	fi
	if [ -f "$tmp_svg_png" ]; then
		preview_image "$tmp_svg_png"
		rm -f "$tmp_svg_png"
		exit 0
	fi
	# Fallback to XML code view
	if command -v bat >/dev/null 2>&1; then
		bat -l xml --color=always --style=numbers "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 5. Audio & Video Multimedia
# ------------------------------------------------------------------------------
case "$EXT" in
mp4 | mkv | mov | avi | webm | flv | m4v | ts | wmv)
	# Video thumbnail extraction
	tmp_vid_thumb="/tmp/fzf-vid-$$.png"
	if command -v ffmpegthumbnailer >/dev/null 2>&1; then
		ffmpegthumbnailer -i "$FILE" -o "$tmp_vid_thumb" -s 800 -q 8 2>/dev/null
	elif command -v ffmpeg >/dev/null 2>&1; then
		ffmpeg -ss 00:00:03 -i "$FILE" -vframes 1 -q:v 2 "$tmp_vid_thumb" -y >/dev/null 2>&1
	fi
	if [ -f "$tmp_vid_thumb" ]; then
		preview_image "$tmp_vid_thumb"
		rm -f "$tmp_vid_thumb"
		exit 0
	fi

	echo "🎬 Video File: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v mediainfo >/dev/null 2>&1; then
		mediainfo "$FILE" 2>/dev/null | head -n 80 && exit 0
	elif command -v ffprobe >/dev/null 2>&1; then
		ffprobe -hide_banner "$FILE" 2>&1 | head -n 80 && exit 0
	elif command -v mdls >/dev/null 2>&1; then
		mdls -name kMDItemDurationSeconds -name kMDItemPixelWidth -name kMDItemPixelHeight "$FILE" 2>/dev/null && exit 0
	fi
	;;
mp3 | wav | flac | aac | ogg | m4a | opus | aiff | alac)
	# Embedded audio cover extraction
	tmp_audio_cover="/tmp/fzf-cover-$$.png"
	if command -v ffmpeg >/dev/null 2>&1; then
		ffmpeg -i "$FILE" -an -vcodec copy "$tmp_audio_cover" -y >/dev/null 2>&1
		if [ -f "$tmp_audio_cover" ]; then
			preview_image "$tmp_audio_cover"
			rm -f "$tmp_audio_cover"
			exit 0
		fi
	fi

	echo "🎵 Audio File: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	# macOS native afinfo (instant CoreAudio analysis)
	if command -v afinfo >/dev/null 2>&1; then
		afinfo "$FILE" 2>/dev/null | head -n 40 && exit 0
	elif command -v mediainfo >/dev/null 2>&1; then
		mediainfo "$FILE" 2>/dev/null | head -n 40 && exit 0
	elif command -v ffprobe >/dev/null 2>&1; then
		ffprobe -hide_banner "$FILE" 2>&1 | head -n 40 && exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 6. Structured Data, Configs & Databases
# ------------------------------------------------------------------------------
case "$EXT" in
json | jsonc | json5)
	if command -v jq >/dev/null 2>&1; then
		jq -C . "$FILE" 2>/dev/null | head -n 250 && exit 0
	elif command -v rich >/dev/null 2>&1; then
		rich "$FILE" --json --force-terminal 2>/dev/null | head -n 250 && exit 0
	fi
	;;
yaml | yml)
	if command -v yq >/dev/null 2>&1; then
		yq -C . "$FILE" 2>/dev/null | head -n 250 && exit 0
	fi
	;;
plist)
	echo "⚙️ macOS Property List: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v plutil >/dev/null 2>&1; then
		if command -v bat >/dev/null 2>&1; then
			plutil -p "$FILE" 2>/dev/null | bat -l yaml --color=always | head -n 250 && exit 0
		else
			plutil -p "$FILE" 2>/dev/null | head -n 250 && exit 0
		fi
	fi
	;;
csv | tsv)
	echo "📊 Tabular Data: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v duckdb >/dev/null 2>&1; then
		duckdb -dark-mode -c "SELECT * FROM read_csv_auto('$FILE') LIMIT 40;" 2>/dev/null && exit 0
	elif command -v rich >/dev/null 2>&1; then
		rich "$FILE" --csv --force-terminal 2>/dev/null | head -n 100 && exit 0
	elif command -v column >/dev/null 2>&1; then
		head -n 100 "$FILE" | column -s, -t 2>/dev/null | head -n 100 && exit 0
	fi
	;;
parquet)
	echo "📊 Parquet Data: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v duckdb >/dev/null 2>&1; then
		duckdb -dark-mode -c "SELECT * FROM read_parquet('$FILE') LIMIT 40;" 2>/dev/null && exit 0
	fi
	;;
ipynb)
	if command -v rich >/dev/null 2>&1; then
		rich "$FILE" --ipynb --force-terminal 2>/dev/null | head -n 250 && exit 0
	elif command -v jq >/dev/null 2>&1; then
		jq -r '.cells[] | select(.cell_type=="code" or .cell_type=="markdown") | if .cell_type=="code" then "```python\n" + (.source | join("")) + "\n```" else (.source | join("")) end' "$FILE" 2>/dev/null | head -n 250 | bat -l markdown --color=always 2>/dev/null && exit 0
	fi
	;;
md | markdown | mdx)
	cols="${FZF_PREVIEW_COLUMNS:-80}"
	if command -v glow >/dev/null 2>&1; then
		glow -p -w "$cols" -s dark "$FILE" 2>/dev/null && exit 0
	elif command -v rich >/dev/null 2>&1; then
		rich "$FILE" --markdown --force-terminal 2>/dev/null | head -n 250 && exit 0
	fi
	;;
html | htm)
	if command -v w3m >/dev/null 2>&1; then
		w3m -dump "$FILE" 2>/dev/null | head -n 150 && exit 0
	elif command -v lynx >/dev/null 2>&1; then
		lynx -dump "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
sqlite | sqlite3 | db | db3 | s3db)
	if command -v sqlite3 >/dev/null 2>&1; then
		echo "🗄️ SQLite Database: ${FILE##*/}"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "=== TABLES ==="
		sqlite3 "$FILE" .tables 2>/dev/null
		echo ""
		echo "=== SCHEMA PREVIEW ==="
		sqlite3 "$FILE" .schema 2>/dev/null | head -n 60
		exit 0
	fi
	;;
pem | crt | cer)
	echo "🔒 X.509 Certificate: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v openssl >/dev/null 2>&1; then
		openssl x509 -in "$FILE" -text -noout 2>/dev/null | grep -E "Subject:|Issuer:|Not Before|Not After|DNS:" | head -n 30 && exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 7. MIME-Type Fallback Classifier
# ------------------------------------------------------------------------------
get_mime
case "$MIME" in
image/*)
	preview_image "$FILE"
	;;
audio/* | video/*)
	echo "🎵 Multimedia Stream: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	if command -v mediainfo >/dev/null 2>&1; then
		mediainfo "$FILE" 2>/dev/null && exit 0
	elif command -v ffprobe >/dev/null 2>&1; then
		ffprobe -hide_banner "$FILE" 2>&1 && exit 0
	fi
	;;
application/pdf | *msword* | *wordprocessingml* | *ms-excel* | *spreadsheetml* | *ms-powerpoint* | *presentationml* | *vnd.oasis.opendocument*)
	preview_document "$FILE"
	;;
text/html)
	if command -v w3m >/dev/null 2>&1; then
		w3m -dump "$FILE" 2>/dev/null | head -n 150 && exit 0
	fi
	;;
esac

# ------------------------------------------------------------------------------
# 8. Mach-O Binaries & Executables Inspection
# ------------------------------------------------------------------------------
if [ -x "$FILE" ] && [ ! -d "$FILE" ] && [[ "$MIME" != text/* && "$MIME" != *"script"* && "$MIME" != *"python"* && "$MIME" != *"perl"* && "$MIME" != *"ruby"* && "$MIME" != *"json"* ]]; then
	echo "⚙️ Mach-O Executable / Binary: ${FILE##*/}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	file "$FILE"
	echo ""
	if command -v codesign >/dev/null 2>&1; then
		echo "=== CODE SIGNATURE ==="
		codesign -dvv "$FILE" 2>&1 | head -n 10
		echo ""
	fi
	if command -v otool >/dev/null 2>&1; then
		echo "=== LINKED DYLIBS (otool -L) ==="
		otool -L "$FILE" 2>/dev/null | head -n 20
		echo ""
	fi
	echo "=== CLI HELP (--help / -h) ==="
	"$FILE" --help 2>&1 | head -n 50 || "$FILE" -h 2>&1 | head -n 50 || echo "No direct help flag supported."
	exit 0
fi

# ------------------------------------------------------------------------------
# 9. Raw Binary / Octet Stream Fallback (Hexdump)
# ------------------------------------------------------------------------------
if [[ "$MIME" == *"octet-stream"* || "$MIME" == *"binary"* ]]; then
	echo "⚙️ Binary Object / Data: $FILE"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	file "$FILE"
	echo ""
	echo "=== HEX DUMP ==="
	if command -v hexyl >/dev/null 2>&1; then
		hexyl --length 384 "$FILE" 2>/dev/null && exit 0
	elif command -v xxd >/dev/null 2>&1; then
		xxd -g 1 -l 256 "$FILE" 2>/dev/null && exit 0
	elif command -v hexdump >/dev/null 2>&1; then
		hexdump -C -n 256 "$FILE" 2>/dev/null && exit 0
	fi
	exit 0
fi

# ------------------------------------------------------------------------------
# 10. Syntax-Highlighted Source Code & Text (Bat / Fallbacks)
# ------------------------------------------------------------------------------
if command -v bat >/dev/null 2>&1; then
	if [ -n "$LINE" ] && [ "$LINE" -gt 0 ] 2>/dev/null; then
		start_line=$((LINE > 25 ? LINE - 25 : 1))
		end_line=$((LINE + 60))
		bat --map-syntax=".ignore:Git Ignore" \
			--map-syntax="*.conf:INI" \
			--color=always \
			--style=numbers,changes,snip \
			--theme=Dracula \
			--highlight-line="$LINE" \
			--line-range="$start_line:$end_line" \
			"$FILE" 2>/dev/null && exit 0
	else
		bat --map-syntax=".ignore:Git Ignore" \
			--map-syntax="*.conf:INI" \
			--color=always \
			--style=numbers,changes \
			--theme=Dracula \
			"$FILE" 2>/dev/null | head -n 250 && exit 0
	fi
elif command -v highlight >/dev/null 2>&1; then
	highlight -O ansi --force "$FILE" 2>/dev/null | head -n 250 && exit 0
fi

# Terminal fallback
cat "$FILE" 2>/dev/null | head -n 250
