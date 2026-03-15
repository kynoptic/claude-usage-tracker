#!/bin/bash
config_file="$HOME/.claude/statusline-config.txt"
if [ -f "$config_file" ]; then
  source "$config_file"
  show_dir=$SHOW_DIRECTORY
  show_branch=$SHOW_BRANCH
  show_usage=$SHOW_USAGE
  show_bar=$SHOW_PROGRESS_BAR
  show_reset=$SHOW_RESET_TIME
  show_time_marker=$SHOW_TIME_MARKER
  show_grey_zone=${SHOW_GREY_ZONE:-0}
  grey_threshold=${GREY_THRESHOLD:-50}
else
  show_dir=1
  show_branch=1
  show_usage=1
  show_bar=1
  show_reset=1
  show_time_marker=1
  show_grey_zone=0
  grey_threshold=50
fi

input=$(cat)
current_dir_path=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | sed 's/"current_dir":"//;s/"$//')
current_dir=$(basename "$current_dir_path")
BLUE=$'\033[0;34m'
GREEN=$'\033[0;32m'
GRAY=$'\033[0;90m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

# 10-level ANSI palette — five zones use levels 3 / 5 / 7 / 10.
# grey/green (< 90%)  → LEVEL_3
# yellow     (90–110%) → LEVEL_5
# orange     (110–150%)→ LEVEL_7
# red        (> 150%) → LEVEL_10
LEVEL_1=$'\033[38;5;22m'   # dark green
LEVEL_2=$'\033[38;5;28m'   # soft green
LEVEL_3=$'\033[38;5;34m'   # medium green
LEVEL_4=$'\033[38;5;190m'  # yellow-green
LEVEL_5=$'\033[38;5;220m'  # gold/amber
LEVEL_6=$'\033[38;5;214m'  # orange-yellow
LEVEL_7=$'\033[38;5;208m'  # orange
LEVEL_8=$'\033[38;5;202m'  # orange-red
LEVEL_9=$'\033[38;5;160m'  # deep red
LEVEL_10=$'\033[38;5;196m' # bright red
SESSION_SECS=18000  # 5-hour session window (Constants.sessionWindow)

# Build components (without separators)
dir_text=""
if [ "$show_dir" = "1" ]; then
  dir_text="${BLUE}${current_dir}${RESET}"
fi

branch_text=""
if [ "$show_branch" = "1" ]; then
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && branch_text="${GREEN}⎇ ${branch}${RESET}"
  fi
fi

usage_text=""
if [ "$show_usage" = "1" ]; then
  swift_result=$(swift "$HOME/.claude/fetch-claude-usage.swift" 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$swift_result" ]; then
    utilization=$(echo "$swift_result" | cut -d'|' -f1)
    resets_at=$(echo "$swift_result" | cut -d'|' -f2)

    if [ -n "$utilization" ] && [ "$utilization" != "ERROR" ]; then
      # Compute elapsed session fraction (integer %, -1 = unavailable)
      # Used for both pacing-aware color selection and the time marker.
      elapsed_secs=-1
      elapsed_frac_pct=-1
      if [ -n "$resets_at" ] && [ "$resets_at" != "null" ]; then
        _marker_iso=$(echo "$resets_at" | sed 's/\.[0-9]*Z$//')
        _marker_epoch=$(date -ju -f "%Y-%m-%dT%H:%M:%S" "$_marker_iso" "+%s" 2>/dev/null)
        if [ -n "$_marker_epoch" ]; then
          _now_epoch=$(date "+%s")
          if [ "$_marker_epoch" -gt "$_now_epoch" ]; then
            _remaining=$((_marker_epoch - _now_epoch))
            _elapsed=$(($SESSION_SECS - _remaining))
            if [ "$_elapsed" -ge 0 ] && [ "$_elapsed" -le "$SESSION_SECS" ]; then
              elapsed_secs="$_elapsed"
              elapsed_frac_pct=$(( (_elapsed * 100) / SESSION_SECS ))
            fi
          fi
        fi
      fi

      # Select color level. Mirrors UsageStatusCalculator.colorLevel (Swift) — keep in sync.
      # Five zones: grey/green → LEVEL_3, yellow → LEVEL_5, orange → LEVEL_7, red → LEVEL_10.
      # Projection fires whenever elapsed > 0; no minimum-elapsed guard.
      # 2>/dev/null guards against the -1 sentinel so non-numeric values fall through to else.
      if [ "$elapsed_frac_pct" -gt 0 ] 2>/dev/null; then
        # Pacing mode: projected = utilization * 100 / elapsed_frac_pct (integer %)
        projected=$(( (utilization * 100) / elapsed_frac_pct ))
        if   [ "$show_grey_zone" = "1" ] && [ "$projected" -lt $grey_threshold ]; then usage_color="$GRAY"     # grey (< threshold)
        elif [ "$projected" -lt 90  ]; then usage_color="$LEVEL_3"   # green (threshold–90%)
        elif [ "$projected" -lt 110 ]; then usage_color="$LEVEL_5"   # yellow (90–110%)
        elif [ "$projected" -le 150 ]; then usage_color="$LEVEL_7"   # orange (110–150%)
        else                                 usage_color="$LEVEL_10"  # red (>150%)
        fi
      else
        # Fallback: raw utilization when timing data unavailable.
        if   [ "$show_grey_zone" = "1" ] && [ "$utilization" -lt $grey_threshold ]; then usage_color="$GRAY"     # grey (< threshold)
        elif [ "$utilization" -lt 90  ]; then usage_color="$LEVEL_3"   # green (threshold–90%)
        elif [ "$utilization" -lt 110 ]; then usage_color="$LEVEL_5"   # yellow (90–110%)
        elif [ "$utilization" -le 150 ]; then usage_color="$LEVEL_7"   # orange (110–150%)
        else                                   usage_color="$LEVEL_10"  # red (>150%)
        fi
      fi

      if [ "$show_bar" = "1" ]; then
        if [ "$utilization" -eq 0 ]; then
          filled_blocks=0
        elif [ "$utilization" -eq 100 ]; then
          filled_blocks=10
        else
          filled_blocks=$(( (utilization * 10 + 50) / 100 ))
        fi
        [ "$filled_blocks" -lt 0 ] && filled_blocks=0
        [ "$filled_blocks" -gt 10 ] && filled_blocks=10
        empty_blocks=$((10 - filled_blocks))

        # Calculate time marker position using pre-computed elapsed_secs
        marker_pos=-1
        # 2>/dev/null: same sentinel guard as the color selection block above.
        if [ "$show_time_marker" = "1" ] && [ "$elapsed_secs" -ge 0 ] 2>/dev/null; then
          # Floor-divide: map 0..$SESSION_SECS elapsed → 0..10 bar positions
          marker_pos=$(( (elapsed_secs * 10) / SESSION_SECS ))
          [ "$marker_pos" -gt 10 ] && marker_pos=10
        fi

        # Build progress bar safely without seq
        progress_bar=" "
        i=0
        while [ $i -lt $filled_blocks ]; do
          if [ $i -eq $marker_pos ]; then
            progress_bar="${progress_bar}│"
          else
            progress_bar="${progress_bar}▓"
          fi
          i=$((i + 1))
        done
        i=0
        while [ $i -lt $empty_blocks ]; do
          pos=$((filled_blocks + i))
          if [ $pos -eq $marker_pos ]; then
            progress_bar="${progress_bar}│"
          else
            progress_bar="${progress_bar}░"
          fi
          i=$((i + 1))
        done
      else
        progress_bar=""
      fi

      reset_time_display=""
      if [ "$show_reset" = "1" ] && [ -n "$resets_at" ] && [ "$resets_at" != "null" ]; then
        iso_time=$(echo "$resets_at" | sed 's/\.[0-9]*Z$//')
        epoch=$(date -ju -f "%Y-%m-%dT%H:%M:%S" "$iso_time" "+%s" 2>/dev/null)

        if [ -n "$epoch" ]; then
          # Detect system time format (12h vs 24h) from macOS locale preferences
          time_format=$(defaults read -g AppleICUForce24HourTime 2>/dev/null)
          if [ "$time_format" = "1" ]; then
            # 24-hour format
            reset_time=$(date -r "$epoch" "+%H:%M" 2>/dev/null)
          else
            # 12-hour format (default)
            reset_time=$(date -r "$epoch" "+%I:%M %p" 2>/dev/null)
          fi
          [ -n "$reset_time" ] && reset_time_display=$(printf " → Reset: %s" "$reset_time")
        fi
      fi

      usage_text="${usage_color}Usage: ${utilization}%${progress_bar}${reset_time_display}${RESET}"
    else
      usage_text="${YELLOW}Usage: ~${RESET}"
    fi
  else
    usage_text="${YELLOW}Usage: ~${RESET}"
  fi
fi

output=""
separator="${GRAY} │ ${RESET}"

[ -n "$dir_text" ] && output="${dir_text}"

if [ -n "$branch_text" ]; then
  [ -n "$output" ] && output="${output}${separator}"
  output="${output}${branch_text}"
fi

if [ -n "$usage_text" ]; then
  [ -n "$output" ] && output="${output}${separator}"
  output="${output}${usage_text}"
fi

printf "%s\n" "$output"
