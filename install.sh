#!/usr/bin/env bash
# mnv — cài đặt, cập nhật, gỡ bỏ. Một chương trình `mnv`, cài theo mục đích của từng máy:
#
#   Máy chính (panel + control + agent):
#     curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- control --domain panel.example.com --email you@example.com
#   Server phụ (agent, chạy container cho máy chính) — mã lấy ở trang Server của panel:
#     curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- agent --join 'mnv1....'
#   Máy cá nhân (lệnh mnv, như kubectl) — Linux/macOS; Windows dùng install.ps1:
#     curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | bash -s -- client
#   Cập nhật lên bản mới nhất (giữ dữ liệu, service không gián đoạn):
#     curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- update
#   Gỡ toàn bộ (thêm --purge để gỡ cả containerd/nerdctl/Caddy mnv đã cài, --keep-data để giữ dữ liệu):
#     curl -fsSL https://raw.githubusercontent.com/kayandk/mnv/main/install.sh | sudo bash -s -- uninstall
#
# Tuỳ chọn chung: --version v0.5.0 (mặc định: bản mới nhất), --yes (không hỏi lại)
# Chỉ hỗ trợ Ubuntu/Debian cho máy chính và server phụ.
set -euo pipefail

REPO=${MNV_REPO:-kayandk/mnv}
VERSION=latest
CMD=""
DOMAIN=""
EMAIL=""
JOIN=""
PUBLIC_IP=""
YES=""
EXTRA=()

if [[ -t 1 ]]; then B=$'\033[1m' G=$'\033[32m' R=$'\033[31m' Y=$'\033[33m' N=$'\033[0m'; else B="" G="" R="" Y="" N=""; fi
say() { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
ok() { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s⚠ %s%s\n' "$Y" "$*" "$N" >&2; }
die() { printf '%slỗi:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
usage() { sed -n 2,17p "$0" 2>/dev/null || true; echo "Xem thêm: https://github.com/$REPO"; }

main() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		control | agent | client | update | uninstall) CMD=$1; shift ;;
		--domain | --panel-domain) DOMAIN=${2:-}; shift 2 ;;
		--email) EMAIL=${2:-}; shift 2 ;;
		--join) JOIN=${2:-}; shift 2 ;;
		--public-ip) PUBLIC_IP=${2:-}; shift 2 ;;
		--version) VERSION=${2:-}; shift 2 ;;
		--yes | -y) YES=--yes; shift ;;
		--purge | --keep-data) EXTRA+=("$1"); shift ;;
		-h | --help | help) usage; exit 0 ;;
		*) die "tham số lạ: $1 (xem: bash install.sh --help)" ;;
		esac
	done
	[[ -n $CMD ]] || { usage; die "chọn việc cần làm: control | agent | client | update | uninstall"; }
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')
	case $(uname -m) in x86_64 | amd64) ARCH=amd64 ;; aarch64 | arm64) ARCH=arm64 ;; *) die "CPU $(uname -m) chưa hỗ trợ" ;; esac
	if [[ -n ${MNV_BASE:-} ]]; then # thử nghiệm: kho phát hành giả (vd. http://127.0.0.1:8000)
		BASE=$MNV_BASE
		TAG=${MNV_TAG:-test}
	elif [[ $VERSION == latest ]]; then
		BASE="https://github.com/$REPO/releases/latest/download"
		TAG=$(curl -fsSLI --max-time 30 -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" | sed 's#.*/tag/##')
		[[ $TAG == v* ]] || die "chưa có bản phát hành nào ở https://github.com/$REPO/releases"
	else
		BASE="https://github.com/$REPO/releases/download/$VERSION"
		TAG=$VERSION
	fi
	TMP=$(mktemp -d)
	trap 'rm -rf "$TMP"' EXIT
	case $CMD in
	client) install_client ;;
	control) need_server; fetch_bundle; fetch_dist; detect_ip; run_setup --role control ;;
	agent)
		[[ -n $JOIN ]] || die "cần mã tham gia: --join 'mnv1....' (tạo ở trang Server của panel, hoặc: sudo mnv control node add <tên>)"
		need_server; fetch_bundle; run_setup --role agent --join "$JOIN" ;;
	update) do_update ;;
	uninstall) do_uninstall ;;
	esac
}

# fetch tải một file của bản phát hành và kiểm tra SHA-256 theo checksums.txt.
fetch() { # fetch <tên asset> <đích>
	local name=$1 dst=$2
	[[ -f $TMP/checksums.txt ]] || curl -fsSL --retry 3 -o "$TMP/checksums.txt" "$BASE/checksums.txt" || die "không tải được checksums.txt của $TAG"
	curl -fsSL --retry 3 --connect-timeout 20 -o "$dst" "$BASE/$name" || die "không tải được $name ($BASE/$name)"
	local want got
	want=$(awk -v f="$name" '$2==f || $2=="*"f {print $1}' "$TMP/checksums.txt")
	[[ -n $want ]] || die "$name không có trong checksums.txt"
	if command -v sha256sum >/dev/null; then got=$(sha256sum "$dst" | awk '{print $1}'); else got=$(shasum -a 256 "$dst" | awk '{print $1}'); fi
	[[ $want == "$got" ]] || die "$name sai checksum (tải lỗi hoặc bị sửa) — thử lại"
}

need_server() {
	[[ $EUID -eq 0 ]] || die "cần quyền root: ... | sudo bash -s -- $CMD"
	[[ $OS == linux ]] || die "máy chính / server phụ chỉ chạy Linux (Ubuntu/Debian). Máy cá nhân: dùng 'client'"
	# shellcheck source=/dev/null
	. /etc/os-release
	[[ $ID == ubuntu || $ID == debian || ${ID_LIKE:-} == *debian* ]] || die "chỉ hỗ trợ Ubuntu/Debian (máy này: $ID)"
}

fetch_bundle() {
	say "Tải mnv $TAG (linux/$ARCH)"
	fetch "mnv_linux_$ARCH.tar.gz" "$TMP/mnv.tgz"
	mkdir -p "$TMP/pkg" && tar -C "$TMP/pkg" -xzf "$TMP/mnv.tgz"
	ok "$("$TMP/pkg/mnv" version)"
}

# Máy chính giữ sẵn mnv cho máy khách để người dùng tải từ panel.
fetch_dist() {
	say "Tải mnv cho máy khách (Windows/macOS/Linux) để panel cho tải"
	mkdir -p "$TMP/dist"
	local t
	for t in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64.exe windows-arm64.exe; do
		fetch "mnv-$t" "$TMP/dist/mnv-$t"
	done
	ok "6 bản"
}

detect_ip() {
	[[ -n $PUBLIC_IP ]] && return
	PUBLIC_IP=$(curl -fsS --max-time 8 https://api.ipify.org 2>/dev/null || curl -fsS --max-time 8 https://ifconfig.me 2>/dev/null || true)
	if [[ $PUBLIC_IP =~ ^[0-9.]+$ ]]; then ok "IP công khai: $PUBLIC_IP"; else PUBLIC_IP=""; warn "không đoán được IP công khai (thêm --public-ip nếu sẽ nối server khác)"; fi
}

run_setup() {
	local args=(--binary "$TMP/pkg/mnv" "$@")
	[[ -d $TMP/dist ]] && args+=(--dist "$TMP/dist")
	[[ -n $DOMAIN ]] && args+=(--panel-domain "$DOMAIN")
	[[ -n $EMAIL ]] && args+=(--email "$EMAIL")
	[[ -n $PUBLIC_IP ]] && args+=(--public-ip "$PUBLIC_IP")
	bash "$TMP/pkg/setup-node.sh" "${args[@]}"
}

# find_client: đường dẫn lệnh mnv máy khách đã cài, kể cả khi chạy qua sudo
# (PATH của root không có ~/.local/bin của người dùng).
find_client() {
	local home="" c
	[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] && home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
	for c in "$(command -v mnv 2>/dev/null || true)" ${home:+"$home/.local/bin/mnv"} "$HOME/.local/bin/mnv" /usr/local/bin/mnv; do
		[[ -n $c && -x $c ]] && { echo "$c"; return; }
	done
}

install_client() {
	local name="mnv-$OS-$ARCH" dir target=${1:-}
	[[ $OS == linux || $OS == darwin ]] || die "Windows: chạy trong PowerShell: irm https://raw.githubusercontent.com/$REPO/main/install.ps1 | iex"
	say "Cài lệnh mnv $TAG ($OS/$ARCH)"
	fetch "$name" "$TMP/mnv"
	chmod +x "$TMP/mnv"
	if [[ -n $target ]]; then
		dir=$(dirname "$target")
		[[ -w $dir ]] || die "$target cần quyền ghi: chạy lại với sudo"
	elif [[ $EUID -eq 0 || -w /usr/local/bin ]]; then dir=/usr/local/bin; else dir=$HOME/.local/bin; mkdir -p "$dir"; fi
	if [[ -f /var/lib/mnv/state.json && $dir == /usr/local/bin ]]; then
		warn "máy này đang là server mnv: lệnh mnv đã có sẵn (máy khách + control/agent). Dùng 'update' để cập nhật."
		exit 1
	fi
	mv -f "$TMP/mnv" "$dir/mnv"
	# Cài qua sudo vào thư mục của người dùng: trả quyền sở hữu cho người đó.
	if [[ $EUID -eq 0 && -n ${SUDO_USER:-} && $dir != /usr/local/bin ]]; then chown "$SUDO_USER": "$dir/mnv" 2>/dev/null || true; fi
	ok "đã cài $dir/mnv ($("$dir/mnv" version))"
	[[ -n $target ]] && return
	case ":$PATH:" in *":$dir:"*) ;; *) warn "thêm vào PATH: echo 'export PATH=\"$dir:\$PATH\"' >> ~/.bashrc" ;; esac
	echo
	echo "Tiếp theo: mnv login https://<domain panel>"
	echo "Gỡ:        rm $dir/mnv && rm -rf ~/.mnv"
}

do_update() {
	local cur
	if [[ -f /var/lib/mnv/state.json ]]; then
		need_server
		say "Cập nhật server mnv lên $TAG"
		fetch_bundle
		if grep -q '"role": *"worker"' /var/lib/mnv/state.json; then
			run_setup --role agent
		else
			fetch_dist
			run_setup --role control
		fi
	elif cur=$(find_client) && [[ -n $cur ]]; then
		say "Cập nhật lệnh mnv (máy khách) $cur: $("$cur" version 2>/dev/null || echo '?') → $TAG"
		install_client "$cur"
	else
		die "máy này chưa cài mnv"
	fi
}

do_uninstall() {
	if [[ $EUID -ne 0 ]]; then
		# Không có sudo: chỉ gỡ được lệnh mnv của người dùng.
		local p
		p=$(find_client)
		[[ -n $p ]] || die "máy này chưa cài mnv"
		[[ -w $(dirname "$p") ]] || die "$p cần quyền root để gỡ: ... | sudo bash -s -- uninstall"
		[[ -f /var/lib/mnv/state.json ]] && die "máy này đang là server mnv: gỡ bằng sudo (... | sudo bash -s -- uninstall)"
		rm -f "$p" && rm -rf "$HOME/.mnv"
		ok "đã gỡ $p và ~/.mnv"
		return
	fi
	if [[ -x /usr/local/lib/mnv/uninstall.sh && -f /usr/local/lib/mnv/lib/progress.sh ]]; then
		bash /usr/local/lib/mnv/uninstall.sh ${YES:+"$YES"} "${EXTRA[@]}"
	else
		fetch_bundle
		bash "$TMP/pkg/uninstall.sh" ${YES:+"$YES"} "${EXTRA[@]}"
	fi
}

main "$@"
