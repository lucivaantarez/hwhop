#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  SATURNITY HOPPER  ·  hwhop
#  Roblox private-server hopper for Termux (non-root)
#  repo: github.com/lucivaantarez/hwhop
# ============================================================
VERSION="1.0.0"

# ---------------- CONFIG ----------------
REPO_RAW="https://raw.githubusercontent.com/lucivaantarez/hwhop/main"
LINKS_URL="$REPO_RAW/links.txt"
HOLD_SECONDS=30                 # seconds to stay in each server before auto-hop
STATE_DIR="$HOME/.hop"
INNER=36                        # panel inner width (keeps borders symmetrical)
# ----------------------------------------

mkdir -p "$STATE_DIR"

# ---- colors: bright + bold so they stay readable on Termux float ----
if [ -z "${NO_COLOR:-}" ]; then
  PINK=$'\033[1;95m'; WHITE=$'\033[1;97m'; CYAN=$'\033[1;96m'
  GREEN=$'\033[1;92m'; YEL=$'\033[1;93m'; RED=$'\033[1;91m'; R=$'\033[0m'
else
  PINK=; WHITE=; CYAN=; GREEN=; YEL=; RED=; R=
fi

# ---- helpers ----
hr(){ local c="$1" n="$2" o="" i; for((i=0;i<n;i++)); do o+="$c"; done; printf '%s' "$o"; }
TOP="╔$(hr ═ "$INNER")╗"; MID="╠$(hr ═ "$INNER")╣"
BOT="╚$(hr ═ "$INNER")╝"; BLANK="║$(hr ' ' "$INNER")║"
line(){ printf "${PINK}%s${R}\n" "$1"; }
clear_screen(){ printf '\033[H\033[2J'; }

center(){ # text color  -> centered row, exact INNER width
  local t="$1" col="$2" len=${#1} pad left right
  pad=$((INNER-len)); ((pad<0)) && pad=0; left=$((pad/2)); right=$((pad-left))
  printf "${PINK}║${R}%*s${col}%s${R}%*s${PINK}║${R}\n" "$left" "" "$t" "$right" ""
}
kv(){ # label value   (3 + 9 + 24 = 36)
  printf "${PINK}║${R}   ${CYAN}%-9s${R}${WHITE}%-24s${R}${PINK}║${R}\n" "$1" "${2:0:24}"
}
menurow(){ # num label  (3 + 1 + 4 + 28 = 36)
  printf "${PINK}║${R}   ${CYAN}%s${R}    ${WHITE}%-28s${R}${PINK}║${R}\n" "$1" "${2:0:28}"
}

# ---- links ----
declare -a LINKS
fetch_links(){
  curl -fsSL "$LINKS_URL" -o "$STATE_DIR/links.txt.tmp" 2>/dev/null \
    && mv "$STATE_DIR/links.txt.tmp" "$STATE_DIR/links.txt"
}
load_links(){
  LINKS=()
  [ -f "$STATE_DIR/links.txt" ] || fetch_links
  [ -f "$STATE_DIR/links.txt" ] || return
  local l
  while IFS= read -r l || [ -n "$l" ]; do
    l="${l%$'\r'}"
    l="${l#"${l%%[![:space:]]*}"}"   # ltrim
    l="${l%"${l##*[![:space:]]}"}"   # rtrim
    [ -z "$l" ] && continue
    [ "${l:0:1}" = "#" ] && continue
    LINKS+=("$l")
  done < "$STATE_DIR/links.txt"
}

# ---- parse a url -> disp_game, code_short ----
disp_game=""; code_short=""
parse_url(){
  local u="$1" g c
  g=$(printf '%s' "$u" | sed -nE 's#.*/games/[0-9]+/([^?]+).*#\1#p' | tr '-' ' ')
  [ -z "$g" ] && g="Roblox"
  disp_game="${g:0:24}"
  c=$(printf '%s' "$u" | sed -nE 's#.*[?&]privateServerLinkCode=([^&]+).*#\1#p')
  if [ -z "$c" ]; then code_short="(no code)"
  elif [ ${#c} -gt 18 ]; then code_short="${c:0:8} … ${c: -8}"
  else code_short="$c"; fi
}

# ---- launch the join (non-root VIEW intent) ----
launch(){ am start -a android.intent.action.VIEW -d "$1" >/dev/null 2>&1; }

# ---- session ----
idx=1; paused=0; total=0
save_session(){ { echo "INDEX=$idx"; echo "PAUSED=$paused"; } > "$STATE_DIR/session"; }
sidx=""; spaused=0
load_session(){
  sidx=""; spaused=0
  [ -f "$STATE_DIR/session" ] || return
  sidx=$(grep -m1 '^INDEX='  "$STATE_DIR/session" | cut -d= -f2)
  spaused=$(grep -m1 '^PAUSED=' "$STATE_DIR/session" | cut -d= -f2)
}
next_idx(){ local n=$((idx+1)); ((n>total)) && n=1;     echo "$n"; }
prev_idx(){ local n=$((idx-1)); ((n<1))     && n=total; echo "$n"; }

# ---------------- screens ----------------
boot_screen(){
  clear_screen
  line "$TOP"; line "$BLANK"; center "SATURNITY HOPPER" "$PINK"; line "$BLANK"; line "$BOT"
  echo
  if [ "${HOP_NET:-fail}" = ok ]; then
    if [ "${HOP_UPDATED:-0}" = 1 ]; then
      printf "   ${CYAN}CHECKING GITHUB …${R}\n"
      printf "     ${WHITE}LOCAL    %s${R}\n" "${HOP_OLD_VER:-none}"
      printf "     ${WHITE}REMOTE   %s${R}   ${YEL}↑ UPDATE FOUND${R}\n" "${HOP_NEW_VER:-?}"
      printf "   ${CYAN}DOWNLOADING  →  hop.sh${R}\n"
      printf "   ${GREEN}NOW ON v%s  ✓${R}\n" "$VERSION"
    else
      printf "   ${CYAN}CHECKING GITHUB …${R}   ${WHITE}v%s${R}  ${GREEN}✓ LATEST${R}\n" "$VERSION"
    fi
  else
    printf "   ${YEL}OFFLINE — using local v%s${R}\n" "$VERSION"
  fi
  printf "   ${CYAN}LAUNCHING …${R}\n"
  sleep 1.2
}

home_screen(){
  local g="—" rd="—" ci
  if ((total>0)); then ci=$idx; ((ci<1||ci>total)) && ci=1; parse_url "${LINKS[ci-1]}"; g="$disp_game"; fi
  if [ -n "$sidx" ]; then
    if [ "${spaused:-0}" = 1 ]; then rd="#$sidx · PAUSED"; else rd="#$sidx"; fi
  fi
  clear_screen
  line "$TOP"; line "$BLANK"
  center "SATURNITY HOPPER" "$PINK"; center "v$VERSION" "$WHITE"; line "$BLANK"
  line "$MID"; line "$BLANK"
  kv "GAME" "$g"; kv "LINKS" "$total"; kv "RESUME" "$rd"; line "$BLANK"
  line "$MID"; line "$BLANK"
  menurow "1" "START HOP"; menurow "2" "CHECK / JUMP TO A LINK"
  menurow "3" "REFRESH LINKS"; menurow "0" "EXIT"; line "$BLANK"
  line "$BOT"
  printf "             ${PINK}SELECT  ›${R} "
}

resume_screen(){
  clear_screen
  line "$TOP"; line "$BLANK"; center "SAVED SESSION" "$PINK"; line "$BLANK"
  line "$MID"; line "$BLANK"
  kv "STOPPED" "#$sidx / $total"; line "$BLANK"
  menurow "Y" "RESUME FROM #$sidx"; menurow "N" "START OVER FROM #1"; line "$BLANK"
  line "$BOT"
  printf "             ${PINK}CHOOSE  ›${R} "
}

# render uses globals: idx,total,disp_game,code_short,hop_state,hop_statecol,status_line,next_line,key1
render_hop(){
  printf '\033[H'
  line "$TOP"; line "$BLANK"
  local sl=${#hop_state} mid=$((26 - sl - 3)); ((mid<1)) && mid=1
  printf "${PINK}║${R}   ${CYAN}HOPPING${R}%*s${hop_statecol}%s${R}   ${PINK}║${R}\n" "$mid" "" "$hop_state"
  line "$BLANK"; line "$MID"; line "$BLANK"
  kv "LINK" "#$idx / $total"; kv "GAME" "$disp_game"; kv "CODE" "$code_short"
  kv "STATUS" "$status_line"; kv "NEXT" "$next_line"
  line "$BLANK"; line "$MID"; line "$BLANK"
  local c1=$((36 - (3 + ${#key1} + 4 + 7 + 4 + 6))); ((c1<1)) && c1=1
  printf "${PINK}║${R}   ${CYAN}%s${R}    ${CYAN}R RETRY${R}    ${CYAN}N NEXT${R}%*s${PINK}║${R}\n" "$key1" "$c1" ""
  printf "${PINK}║${R}   ${CYAN}B BACK${R}     ${CYAN}0 MENU${R}%*s${PINK}║${R}\n" 16 ""
  line "$BLANK"; line "$BOT"
  printf "                ${PINK}›${R} "
}

no_links_screen(){
  clear_screen
  line "$TOP"; line "$BLANK"; center "NO LINKS FOUND" "$YEL"; line "$BLANK"
  line "$MID"; line "$BLANK"
  kv "FIX" "add links to the repo"; kv "FILE" "hwhop/links.txt"; line "$BLANK"
  line "$BOT"
  printf "             ${PINK}press enter${R} "; read -r _
}

# ---------------- hop loop ----------------
run_hop_loop(){
  clear_screen
  local remaining relaunch k pk
  while true; do
    parse_url "${LINKS[idx-1]}"
    launch "${LINKS[idx-1]}"
    paused=0; key1="P PAUSE"; hop_state="RUNNING"; hop_statecol="$GREEN"
    status_line="JOINED · HOLDING"
    remaining=$HOLD_SECONDS
    relaunch=0
    while ((remaining>0)); do
      next_line="AUTO-HOP IN ${remaining}s"
      render_hop
      if read -rsn1 -t 1 k; then
        case "$k" in
          p|P)
            paused=1; save_session
            hop_state="PAUSED"; hop_statecol="$YEL"; key1="P RESUME"
            status_line="PAUSED · SAVED"; next_line="WAITING FOR YOU"; render_hop
            while read -rsn1 pk; do
              case "$pk" in
                p|P) paused=0; hop_state="RUNNING"; hop_statecol="$GREEN"
                     key1="P PAUSE"; status_line="JOINED · HOLDING"; break;;
                r|R) relaunch=1; break;;
                n|N) idx=$(next_idx); relaunch=1; break;;
                b|B) idx=$(prev_idx); relaunch=1; break;;
                0)   save_session; return;;
              esac
            done
            ((relaunch==1)) && break
            ;;
          r|R) break;;                    # retry same link
          n|N) idx=$(next_idx); break;;   # next link
          b|B) idx=$(prev_idx); break;;   # previous link
          0)   save_session; return;;     # back to menu
        esac
      else
        ((remaining--))
      fi
    done
    ((remaining==0)) && idx=$(next_idx)    # countdown ran out -> auto-hop
    save_session
  done
}

start_hop(){
  load_links; total=${#LINKS[@]}
  ((total==0)) && { no_links_screen; return; }
  load_session
  if [ -n "$sidx" ] && ((sidx>=1 && sidx<=total)); then
    resume_screen; read -r a
    case "$a" in n|N) idx=1;; *) idx=$sidx;; esac     # enter or y = resume
  else idx=1; fi
  run_hop_loop
}

check_jump(){
  load_links; total=${#LINKS[@]}
  ((total==0)) && { no_links_screen; return; }
  local n s full
  while true; do
    clear_screen
    line "$TOP"; line "$BLANK"; center "CHECK / JUMP" "$PINK"; line "$BLANK"
    line "$MID"; line "$BLANK"
    kv "TOTAL" "$total LINKS"; kv "RANGE" "1 – $total   (0 back)"; line "$BLANK"
    line "$BOT"
    printf "   ${PINK}›${R}  "; read -r n
    [ "$n" = "0" ] && return
    if [[ "$n" =~ ^[0-9]+$ ]] && ((n>=1 && n<=total)); then
      parse_url "${LINKS[n-1]}"
      full=$(printf '%s' "${LINKS[n-1]}" | sed -nE 's#.*[?&]privateServerLinkCode=([^&]+).*#\1#p')
      echo
      printf "   ${CYAN}#%s${R}    ${WHITE}%s${R}\n" "$n" "$disp_game"
      printf "   ${CYAN}CODE${R}    ${WHITE}%s${R}\n\n" "${full:-(no code)}"
      printf "   ${CYAN}S${R}    ${WHITE}START HOPPING FROM #%s${R}\n" "$n"
      printf "   ${CYAN}0${R}    ${WHITE}BACK${R}\n"
      printf "   ${PINK}›${R}  "; read -r s
      case "$s" in s|S) idx=$n; paused=0; run_hop_loop; return;; esac
    fi
  done
}

refresh_links(){
  local before after diff sign
  load_links; before=${#LINKS[@]}
  clear_screen
  line "$TOP"; line "$BLANK"; center "REFRESHING FROM GITHUB …" "$PINK"; line "$BLANK"
  line "$MID"; line "$BLANK"
  fetch_links
  load_links; after=${#LINKS[@]}; total=$after
  diff=$((after-before)); sign="+"; ((diff<0)) && sign=""
  kv "BEFORE" "$before"; kv "AFTER" "$after      ${sign}${diff} NEW"; line "$BLANK"
  line "$BOT"
  printf "             ${PINK}press enter${R} "; read -r _
}

exit_screen(){
  save_session
  clear_screen
  printf "   ${CYAN}SAVING SESSION …${R}   ${WHITE}#%s${R}\n" "${idx:-1}"
  printf "   ${GREEN}SAVED ✓${R}\n\n"
  printf "        ${PINK}SATURNITY  ✦  BYE${R}\n\n"
}

# ---------------- main ----------------
boot_screen
while true; do
  load_links; total=${#LINKS[@]}; load_session
  home_screen; read -r choice
  case "$choice" in
    1) start_hop;;
    2) check_jump;;
    3) refresh_links;;
    0|q|Q) exit_screen; exit 0;;
    *) ;;
  esac
done
