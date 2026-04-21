#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# xdsrun install.sh
# 需要管理员权限运行：
#   sudo ./install.sh
# ============================================================

# ====== 内置安装配置 ======
XDSRUN_DIR="/opt/xdsrun"
XDSRUN_VERSION="1.1.3"

TMP_DIR="/tmp"

XDSRUN_BIN="${XDSRUN_DIR}/xdsrun"
WATCHDOG_SCRIPT="${XDSRUN_DIR}/xdsrun-watchdog"
WATCHDOG_CONFIG="${XDSRUN_DIR}/xdsrun-watchdog.conf"

CRON_MARK_BEGIN="# >>> xdsrun-watchdog cron >>>"
CRON_MARK_END="# <<< xdsrun-watchdog cron <<<"

# 运行时根据架构自动设置
ARCH=""
XDSRUN_PKG_ARCH=""
ZIP_FILE=""
XDSRUN_URL=""

# crontab 配置，由用户输入的间隔解析生成
CRON_EXPR=""
INTERVAL_DESC=""
INPUT_INTERVAL=""

# ============================================================
# 工具函数
# ============================================================

log() {
    echo "[INFO] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

err() {
    echo "[ERROR] $*" >&2
    exit 1
}

ask_yes_no() {
    local prompt="$1"
    local answer

    while true; do
        read -r -p "${prompt} [y/N]: " answer
        case "${answer}" in
            y|Y|yes|YES|Yes)
                return 0
                ;;
            n|N|no|NO|No|"")
                return 1
                ;;
            *)
                echo "请输入 y 或 n。"
                ;;
        esac
    done
}

need_root() {
    if [ "${EUID}" -ne 0 ]; then
        err "请使用管理员权限运行：sudo ./install.sh"
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_pkg_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

detect_arch_and_set_url() {
    ARCH="$(uname -m)"

    case "${ARCH}" in
        x86_64|amd64)
            XDSRUN_PKG_ARCH="amd64"
            ;;
        aarch64|arm64)
            XDSRUN_PKG_ARCH="arm64"
            ;;
        *)
            err "不支持的 CPU 架构：${ARCH}。当前仅支持 x86_64/amd64 和 aarch64/arm64。"
            ;;
    esac

    ZIP_FILE="${TMP_DIR}/xdsrun_${XDSRUN_VERSION}_linux_${XDSRUN_PKG_ARCH}.zip"
    XDSRUN_URL="https://github.com/NanCunChild/xdsrun-login/releases/download/v${XDSRUN_VERSION}/xdsrun_${XDSRUN_VERSION}_linux_${XDSRUN_PKG_ARCH}.zip"

    log "检测到系统架构：${ARCH}，将使用安装包架构：${XDSRUN_PKG_ARCH}"
    log "下载链接：${XDSRUN_URL}"
}

install_packages() {
    local pkgs=("$@")
    local pm
    pm="$(detect_pkg_manager)"

    if [ "${pm}" = "unknown" ]; then
        err "无法识别包管理器，请手动安装：${pkgs[*]}"
    fi

    log "尝试安装缺失依赖：${pkgs[*]}"

    case "${pm}" in
        apt)
            apt-get update
            apt-get install -y "${pkgs[@]}"
            ;;
        dnf)
            dnf install -y "${pkgs[@]}"
            ;;
        yum)
            yum install -y "${pkgs[@]}"
            ;;
        pacman)
            pacman -Sy --noconfirm "${pkgs[@]}"
            ;;
        zypper)
            zypper install -y "${pkgs[@]}"
            ;;
    esac
}

ensure_deps() {
    local missing=()

    command_exists wget || missing+=("wget")
    command_exists unzip || missing+=("unzip")

    if ! command_exists crontab; then
        local pm
        pm="$(detect_pkg_manager)"

        case "${pm}" in
            apt)
                missing+=("cron")
                ;;
            dnf|yum)
                missing+=("cronie")
                ;;
            pacman)
                missing+=("cronie")
                ;;
            zypper)
                missing+=("cron")
                ;;
            *)
                missing+=("cron")
                ;;
        esac
    fi

    if [ "${#missing[@]}" -gt 0 ]; then
        install_packages "${missing[@]}"
    fi

    command_exists wget || err "wget 安装失败或不可用"
    command_exists unzip || err "unzip 安装失败或不可用"
    command_exists crontab || err "crontab 不可用，请检查 cron/cronie 是否安装成功"
}

enable_cron_service() {
    if command_exists systemctl; then
        if systemctl list-unit-files | grep -q '^cron\.service'; then
            systemctl enable --now cron >/dev/null 2>&1 || true
        elif systemctl list-unit-files | grep -q '^crond\.service'; then
            systemctl enable --now crond >/dev/null 2>&1 || true
        elif systemctl list-unit-files | grep -q '^cronie\.service'; then
            systemctl enable --now cronie >/dev/null 2>&1 || true
        fi
    fi
}

parse_interval_to_cron() {
    local interval="$1"
    local num unit

    if [[ ! "${interval}" =~ ^([1-9][0-9]*)([mhd])$ ]]; then
        return 1
    fi

    num="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[2]}"

    case "${unit}" in
        m)
            if [ "${num}" -gt 59 ]; then
                return 1
            fi
            CRON_EXPR="*/${num} * * * *"
            INTERVAL_DESC="每 ${num} 分钟"
            ;;
        h)
            if [ "${num}" -gt 23 ]; then
                return 1
            fi
            CRON_EXPR="0 */${num} * * *"
            INTERVAL_DESC="每 ${num} 小时"
            ;;
        d)
            CRON_EXPR="0 0 */${num} * *"
            INTERVAL_DESC="每 ${num} 天"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

prompt_config() {
    echo
    read -r -p "请输入校园网用户名: " INPUT_USERNAME

    while [ -z "${INPUT_USERNAME}" ]; do
        echo "用户名不能为空。"
        read -r -p "请输入校园网用户名: " INPUT_USERNAME
    done

    read -r -s -p "请输入校园网密码: " INPUT_PASSWORD
    echo

    while [ -z "${INPUT_PASSWORD}" ]; do
        echo "密码不能为空。"
        read -r -s -p "请输入校园网密码: " INPUT_PASSWORD
        echo
    done

    echo
    echo "请输入 watchdog 执行间隔："
    echo "  数字+时间单位（m、h、d）"
    echo "  m 表示分钟 / h 表示小时 / d 表示天"
    read -r -p "执行间隔 [默认: 5m]: " INPUT_INTERVAL

    if [ -z "${INPUT_INTERVAL}" ]; then
        INPUT_INTERVAL="5m"
    fi

    while ! parse_interval_to_cron "${INPUT_INTERVAL}"; do
        echo "执行间隔格式错误。请输入类似 5m、2h、1d 的格式。"
        echo "限制：分钟 1-59，小时 1-23，天为正整数。"
        read -r -p "执行间隔 [默认: 5m]: " INPUT_INTERVAL

        if [ -z "${INPUT_INTERVAL}" ]; then
            INPUT_INTERVAL="5m"
        fi
    done
}

install_xdsrun_bin() {
    mkdir -p "${XDSRUN_DIR}"

    if [ -f "${XDSRUN_BIN}" ]; then
        log "检测到 xdsrun 已存在：${XDSRUN_BIN}"

        if ask_yes_no "是否重新下载并安装 xdsrun？"; then
            log "将重新安装 xdsrun"
            rm -f "${XDSRUN_BIN}"
        else
            log "跳过 xdsrun 重新安装，仅确保其具有可执行权限"
            chmod +x "${XDSRUN_BIN}"
            return
        fi
    fi

    log "下载 xdsrun：${XDSRUN_URL}"
    wget -O "${ZIP_FILE}" "${XDSRUN_URL}"

    local extract_dir
    extract_dir="$(mktemp -d /tmp/xdsrun_extract.XXXXXX)"

    log "解压：${ZIP_FILE}"
    unzip -o "${ZIP_FILE}" -d "${extract_dir}" >/dev/null

    if [ ! -f "${extract_dir}/xdsrun" ]; then
        rm -rf "${extract_dir}"
        err "解压后没有找到 xdsrun 二进制程序"
    fi

    mv "${extract_dir}/xdsrun" "${XDSRUN_BIN}"
    chmod +x "${XDSRUN_BIN}"

    rm -rf "${extract_dir}"

    log "xdsrun 已安装到：${XDSRUN_BIN}"
}

write_watchdog_config() {
    log "写入 watchdog 配置文件：${WATCHDOG_CONFIG}"

    cat > "${WATCHDOG_CONFIG}" <<EOF
# xdsrun-watchdog 配置文件
# 由 install.sh 生成

# ====== PING 配置 ======
PING_TARGET="www.baidu.com"
PING_COUNT=3
PING_TIMEOUT=3

# ====== 登录配置 ======
USERNAME="${INPUT_USERNAME}"
PASSWORD="${INPUT_PASSWORD}"

# ====== LOG 配置 ======
LOG_DIR="${XDSRUN_DIR}/log"
EOF

    chmod 600 "${WATCHDOG_CONFIG}"
}

write_watchdog_script() {
    if [ -f "${WATCHDOG_SCRIPT}" ]; then
        log "检测到 xdsrun-watchdog 已存在：${WATCHDOG_SCRIPT}"

        if ask_yes_no "是否重新生成 xdsrun-watchdog 脚本？"; then
            log "将重新生成 xdsrun-watchdog"
            rm -f "${WATCHDOG_SCRIPT}"
        else
            log "跳过 xdsrun-watchdog 重新生成，仅确保其具有可执行权限"
            chmod +x "${WATCHDOG_SCRIPT}"
            return
        fi
    fi

    log "写入 watchdog 脚本：${WATCHDOG_SCRIPT}"

    cat > "${WATCHDOG_SCRIPT}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# xdsrun-watchdog
# 自动检测网络，断网时调用 xdsrun 登录
# ============================================================

# ====== 脚本内置路径配置 ======
XDSRUN_BIN="${XDSRUN_BIN}"
CONFIG_FILE="${WATCHDOG_CONFIG}"

# ====== 加载配置文件 ======
if [ -f "\${CONFIG_FILE}" ]; then
    # shellcheck disable=SC1090
    source "\${CONFIG_FILE}"
else
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] 配置文件不存在：\${CONFIG_FILE}" >&2
    exit 1
fi

# ====== 基础检查 ======
if [ -z "\${PING_TARGET:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] PING_TARGET 为空，请检查配置文件：\${CONFIG_FILE}" >&2
    exit 1
fi

if [ -z "\${PING_COUNT:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] PING_COUNT 为空，请检查配置文件：\${CONFIG_FILE}" >&2
    exit 1
fi

if [ -z "\${PING_TIMEOUT:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] PING_TIMEOUT 为空，请检查配置文件：\${CONFIG_FILE}" >&2
    exit 1
fi

if [ -z "\${USERNAME:-}" ] || [ -z "\${PASSWORD:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] USERNAME 或 PASSWORD 为空，请检查配置文件：\${CONFIG_FILE}" >&2
    exit 1
fi

if [ -z "\${LOG_DIR:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] LOG_DIR 为空，请检查配置文件：\${CONFIG_FILE}" >&2
    exit 1
fi

if [ ! -x "\${XDSRUN_BIN}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] xdsrun 不存在或不可执行：\${XDSRUN_BIN}" >&2
    exit 1
fi

# ====== 检测网络是否在线 ======
if ping -c "\${PING_COUNT}" -W "\${PING_TIMEOUT}" "\${PING_TARGET}" >/dev/null 2>&1; then
    exit 0
fi

# ====== LOG 配置 ======
MONTH_STR="\$(date '+%Y-%m')"
LOGFILE="\${LOG_DIR}/xdsrun_\${MONTH_STR}.log"

# ====== 日志准备 ======
mkdir -p "\${LOG_DIR}"
timestamp="\$(date '+%Y-%m-%d %H:%M:%S')"

# ====== 登录西电校园网 ======
output="\$("\${XDSRUN_BIN}" -u "\${USERNAME}" -p "\${PASSWORD}" 2>&1)"
echo "[\${timestamp}] \${output}" >> "\${LOGFILE}"
EOF

    chmod +x "${WATCHDOG_SCRIPT}"
}

install_cron() {
    log "配置 root crontab，${INTERVAL_DESC}执行一次 watchdog"

    local cron_line
    cron_line="${CRON_EXPR} ${WATCHDOG_SCRIPT} >/dev/null 2>&1"

    local current_cron
    current_cron="$(mktemp /tmp/xdsrun_cron.XXXXXX)"

    crontab -l 2>/dev/null > "${current_cron}" || true

    sed -i.bak "/${CRON_MARK_BEGIN}/,/${CRON_MARK_END}/d" "${current_cron}"

    grep -v -F "${WATCHDOG_SCRIPT}" "${current_cron}" > "${current_cron}.new" || true
    mv "${current_cron}.new" "${current_cron}"

    {
        echo "${CRON_MARK_BEGIN}"
        echo "${cron_line}"
        echo "${CRON_MARK_END}"
    } >> "${current_cron}"

    crontab "${current_cron}"

    rm -f "${current_cron}" "${current_cron}.bak"

    log "crontab 已配置：${cron_line}"
}

main() {
    need_root
    detect_arch_and_set_url
    ensure_deps
    enable_cron_service

    install_xdsrun_bin
    write_watchdog_script

    prompt_config

    write_watchdog_config
    install_cron

    echo
    log "安装完成。"
    echo "系统架构：${ARCH}"
    echo "安装包架构：${XDSRUN_PKG_ARCH}"
    echo "下载链接：${XDSRUN_URL}"
    echo "xdsrun 程序：${XDSRUN_BIN}"
    echo "watchdog 脚本：${WATCHDOG_SCRIPT}"
    echo "watchdog 配置：${WATCHDOG_CONFIG}"
    echo "日志目录：${XDSRUN_DIR}/log"
    echo "执行间隔：${INTERVAL_DESC}"
    echo
    echo "可手动测试："
    echo "  sudo ${WATCHDOG_SCRIPT}"
    echo
    echo "查看 root crontab："
    echo "  sudo crontab -l"
}

main "$@"
