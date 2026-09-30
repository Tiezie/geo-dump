#!/bin/sh
# Install the two independent geo-dump tools. POSIX shell; Linux only.
set -eu

REPOSITORY='Tiezie/geo-dump'
REF=${GEO_DUMP_REF:-main}
BASE_URL=${GEO_DUMP_BASE_URL:-https://raw.githubusercontent.com/$REPOSITORY/$REF}
INSTALL_DIR=${GEO_DUMP_INSTALL_DIR:-/usr/local/bin}
SOURCE_DIR=${GEO_DUMP_SOURCE_DIR:-}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }

case ${1:-} in
    -h|--help)
        printf '%s\n' '用法：sh install.sh' \
            '默认安装到 /usr/local/bin；系统安装请使用 root 或 sudo。' \
            'GEO_DUMP_INSTALL_DIR 可指定其他安装目录。' \
            'GEO_DUMP_REF 可指定分支或提交。' \
            '安装工具，不下载或修改 geosite.dat / geoip.dat。'
        exit 0 ;;
    '') ;;
    *) die '不支持该参数；使用 --help 查看说明。' ;;
esac

[ "$(uname -s)" = Linux ] || die '一键安装仅支持 Linux；其他系统可直接使用 Python 3 运行脚本。'
case "$INSTALL_DIR" in /*) ;; *) die '安装目录必须是绝对路径。' ;; esac
if [ "$INSTALL_DIR" = /usr/local/bin ] && [ "$(id -u)" -ne 0 ]; then
    die '系统安装需要 root：请以 root 运行，或使用 sudo sh install.sh。'
fi

# Install only a missing Python runtime, never upgrade the whole system.
if ! command -v python3 >/dev/null 2>&1; then
    [ "$(id -u)" -eq 0 ] || die '缺少 Python 3，请先安装 python3。'
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y python3
    elif command -v yum >/dev/null 2>&1; then
        yum install -y python3
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache python3
    else
        die '无法自动安装 Python 3，请使用系统包管理器安装 python3。'
    fi
fi
for tool in sha256sum mktemp install; do
    command -v "$tool" >/dev/null 2>&1 || die "缺少依赖：$tool"
done
if [ -z "$SOURCE_DIR" ]; then
    command -v curl >/dev/null 2>&1 || die '缺少 curl，请先用系统包管理器安装 curl。'
fi

tmp_dir=$(mktemp -d)
rollback=0
cleanup() {
    rc=$?
    trap - EXIT HUP INT TERM
    if [ "$rollback" -eq 1 ]; then
        for name in geosite-dump geoip-dump; do
            if [ -e "$tmp_dir/old-$name" ] || [ -L "$tmp_dir/old-$name" ]; then
                cp -Pp "$tmp_dir/old-$name" "$INSTALL_DIR/$name" || true
            elif [ -f "$tmp_dir/absent-$name" ]; then
                rm -f -- "$INSTALL_DIR/$name"
            fi
        done
    fi
    rm -rf -- "$tmp_dir"
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

printf '%s\n' '下载并校验 geosite-dump / geoip-dump…'
for name in geosite-dump geoip-dump SHA256SUMS; do
    if [ -n "$SOURCE_DIR" ]; then
        cp "$SOURCE_DIR/$name" "$tmp_dir/$name"
    else
        curl --fail --silent --show-error --location --retry 3 \
            --connect-timeout 15 --max-time 120 \
            "$BASE_URL/$name" -o "$tmp_dir/$name"
    fi
done
(cd "$tmp_dir" && sha256sum -c SHA256SUMS)
python3 - "$tmp_dir" <<'PY'
import ast
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
for name in ('geosite-dump', 'geoip-dump'):
    ast.parse((root / name).read_text(encoding='utf-8'), filename=name)
PY
python3 "$tmp_dir/geosite-dump" --help >/dev/null
python3 "$tmp_dir/geoip-dump" --help >/dev/null

mkdir -p "$INSTALL_DIR"
for name in geosite-dump geoip-dump; do
    [ ! -d "$INSTALL_DIR/$name" ] || die "目标是目录，不能覆盖：$INSTALL_DIR/$name"
    if [ -e "$INSTALL_DIR/$name" ] || [ -L "$INSTALL_DIR/$name" ]; then
        cp -Pp "$INSTALL_DIR/$name" "$tmp_dir/old-$name"
    else
        : > "$tmp_dir/absent-$name"
    fi
done
rollback=1
for name in geosite-dump geoip-dump; do
    # Remove an old symlink before installing to avoid changing its target.
    rm -f -- "$INSTALL_DIR/$name"
    install -m 755 "$tmp_dir/$name" "$INSTALL_DIR/$name"
done
"$INSTALL_DIR/geosite-dump" --help >/dev/null
"$INSTALL_DIR/geoip-dump" --help >/dev/null
rollback=0

printf '\n安装成功：\n  %s/geosite-dump\n  %s/geoip-dump\n' "$INSTALL_DIR" "$INSTALL_DIR"
case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) printf '请将 %s 加入 PATH，或使用绝对路径执行。\n' "$INSTALL_DIR" ;;
esac
printf '%s\n' '开始使用：geosite-dump info / geoip-dump info'
if [ ! -f /usr/local/share/xray/geosite.dat ] || [ ! -f /usr/local/share/xray/geoip.dat ]; then
    printf '%s\n' '提示：默认数据库不齐全；请安装 Xray 数据库，或用 -f 指定已有 .dat 文件。'
fi
