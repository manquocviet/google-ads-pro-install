#!/bin/bash
# Cài Google Ads Pro trên Mac bằng một lệnh (dán vào Terminal). Lệnh do người quản lý tạo bằng tools/invite.py:
#   curl -fsSL https://raw.githubusercontent.com/manquocviet/google-ads-pro-install/main/install.sh | bash -s gap1.…
# Mã mời gap1.… chứa địa chỉ repo và một khoá chỉ đọc riêng cho người này (thu hồi được). Bản cũ dùng token vẫn chạy:
#   T=TOKEN; curl -fsSL -H "Authorization: Bearer $T" -H "Accept: application/vnd.github.raw" https://api.github.com/repos/manquocviet/google-ads-pro/contents/install.sh | bash -s $T
# Thiếu Git/Python thì tự cài bộ công cụ dòng lệnh của Apple, rồi tải tool về ~/google-ads-pro, tạo icon trên Desktop và mở tool.
set -u
CODE="${1:-}"
REPO="manquocviet/google-ads-pro"
KEY="$HOME/.ssh/google_ads_pro_ed25519"
SSHCMD="ssh -i \"$KEY\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15"
DIR="$HOME/google-ads-pro"
APP="$DIR/Google Ads Pro.app"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mLỖI: %s\033[0m\n' "$*"; exit 1; }

[ -n "$CODE" ] || fail "Thiếu mã mời. Dán nguyên dòng lệnh người gửi tool đưa cho bạn (dòng kết thúc bằng mã gap1.…)."

# 1. Git và Python 3 có sẵn trong bộ công cụ dòng lệnh (Command Line Tools) của Apple
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  say "Máy chưa có Git/Python. Một cửa sổ của Apple sẽ hiện ra: bấm \"Cài đặt\" (Install), đồng ý điều khoản và chờ cài xong (5-15 phút)."
  /usr/bin/xcode-select --install >/dev/null 2>&1
  printf 'Đang chờ cài xong'
  for _ in $(seq 720); do
    /usr/bin/xcode-select -p >/dev/null 2>&1 && [ -x /usr/bin/git ] && /usr/bin/git --version >/dev/null 2>&1 && break
    printf '.'; sleep 5
  done
  echo
  /usr/bin/xcode-select -p >/dev/null 2>&1 || fail "Chưa cài xong công cụ dòng lệnh. Cài xong rồi dán lại lệnh cài."
fi
PY="$(command -v python3 || echo /usr/bin/python3)"
"$PY" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null \
  || fail "Python trên máy quá cũ hoặc không chạy được. Cài Python mới tại https://www.python.org/downloads/ rồi dán lại lệnh cài."

# 2. Mã mời: lưu khoá chỉ đọc của máy này, git dùng khoá đó để tải và cập nhật tool
export GIT_TERMINAL_PROMPT=0
if [[ "$CODE" == gap1.* ]]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  OLDKEY=""; [ -f "$KEY" ] && OLDKEY="$(cat "$KEY")"
  URL="$("$PY" - "$CODE" "$KEY" <<'PYEOF'
import base64, json, os, sys
code, path = sys.argv[1], sys.argv[2]
try:
    s = code.strip()[5:]
    d = json.loads(base64.urlsafe_b64decode(s + "=" * (-len(s) % 4)))
    remote, key = d["remote"], d["key"]
    assert "OPENSSH PRIVATE KEY" in key and remote
except Exception:
    sys.exit(1)
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    f.write(key if key.endswith("\n") else key + "\n")
os.chmod(path, 0o600)
print(remote)
PYEOF
)" || fail "Mã mời không đúng. Copy lại nguyên dòng lệnh người gửi đưa (không thiếu ký tự) rồi chạy lại."
  export GIT_SSH_COMMAND="$SSHCMD"
  if ! git ls-remote -q "$URL" >/dev/null 2>&1; then
    if [ -n "$OLDKEY" ]; then printf '%s\n' "$OLDKEY" > "$KEY"; chmod 600 "$KEY"; fi
    fail "Mã mời chưa dùng được (đã bị thu hồi, hoặc mạng/GitHub đang lỗi). Thử lại sau ít phút; vẫn lỗi thì nhờ người gửi tạo mã mới."
  fi
else
  URL="https://x-access-token:$CODE@github.com/$REPO.git"  # cách cũ: token GitHub
fi
use_key() { [[ "$CODE" == gap1.* ]] && git -C "$DIR" config core.sshCommand "$SSHCMD"; return 0; }

# 3. Tải tool (đã có thì chỉ cập nhật)
if [ -d "$DIR/.git" ]; then
  say "Đã có tool tại $DIR, đang cập nhật..."
  git -C "$DIR" remote set-url origin "$URL"
  use_key
  git -C "$DIR" pull --ff-only -q || say "Không cập nhật được, dùng bản đang có."
else
  say "Đang tải Google Ads Pro về $DIR ..."
  git clone -q "$URL" "$DIR" || fail "Không tải được tool. Kiểm tra lại mã mời (có thể đã bị thu hồi) và mạng."
  use_key
fi
chmod +x "$DIR/start.command" "$APP/Contents/MacOS/launcher" 2>/dev/null

# 4. Icon cũ trên Desktop (bản đóng gói riêng): thay phần chạy bên trong để nó cũng dùng bản GitHub, tự cập nhật
for OLD in "$HOME/Desktop/Google App Campaign Tool.app" "$HOME/Desktop/Google Ads Pro.app"; do
  [ -d "$OLD/Contents" ] && [ ! -L "$OLD" ] || continue
  say "Cập nhật icon trên Desktop để tự lấy bản mới từ GitHub..."
  cp "$APP/Contents/MacOS/launcher" "$OLD/Contents/MacOS/launcher" && chmod +x "$OLD/Contents/MacOS/launcher" \
    && cp "$APP/Contents/Info.plist" "$OLD/Contents/Info.plist" \
    && cp "$APP/Contents/Resources/AppIcon.icns" "$OLD/Contents/Resources/AppIcon.icns" \
    && rm -rf "$OLD/Contents/Resources/tool" \
    || { say "Không sửa được icon cũ trên Desktop (có thể cần cho Terminal quyền truy cập Desktop)."; continue; }
  [ "$OLD" = "$HOME/Desktop/Google Ads Pro.app" ] || mv "$OLD" "$HOME/Desktop/Google Ads Pro.app" 2>/dev/null
  touch "$HOME/Desktop/Google Ads Pro.app" 2>/dev/null
done

# 5. Icon trên Desktop (alias tới icon trong thư mục tool)
if ! ls "$HOME/Desktop" 2>/dev/null | grep -q "^Google Ads Pro"; then
  /usr/bin/osascript -e "tell application \"Finder\" to make alias file to POSIX file \"$APP\" at desktop" >/dev/null 2>&1 \
    && say "Đã tạo icon \"Google Ads Pro\" trên Desktop. Lần sau bấm đúp icon đó để mở tool (có thể kéo vào Dock)."
fi

# 6. Mở tool (lần đầu cài thư viện 1-2 phút, có thông báo góc màn hình)
say "Đang mở tool, lần đầu cần 1-2 phút để cài thư viện..."
/usr/bin/open "$APP" || "$DIR/start.command"
