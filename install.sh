#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# xdsrun install.sh
# ============================================================

# ====== Built-in installation config ======
XDSRUN_DIR="/opt/xdsrun"
XDSRUN_VERSION="1.1.3"

TMP_DIR="/tmp"
BIN_LINK_DIR="/usr/local/bin"

XDSRUN_BIN="${XDSRUN_DIR}/xdsrun"
WATCHDOG_SCRIPT="${XDSRUN_DIR}/xdsrun-watchdog"
WATCHDOG_CONFIG="${XDSRUN_DIR}/xdsrun-watchdog.conf"
XDSRUN_BIN_LINK="${BIN_LINK_DIR}/xdsrun"
WATCHDOG_BIN_LINK="${BIN_LINK_DIR}/xdsrun-watchdog"

CRON_MARK_BEGIN="# >>> xdsrun-watchdog cron >>>"
CRON_MARK_END="# <<< xdsrun-watchdog cron <<<"

# Runtime arch detection
ARCH=""
XDSRUN_PKG_ARCH=""
ZIP_FILE=""
XDSRUN_URL=""

# crontab config, parsed from user input interval
CRON_EXPR=""
INTERVAL_DESC=""
INPUT_INTERVAL=""
INPUT_USERNAME=""
INPUT_PASSWORD=""

# ============================================================
# i18n
# ============================================================

msg() {
    case "$1_${LANG_CODE:-zh}" in
        invalid_yes_no_en) printf '%s\n' 'Please enter y or n.' ;;
        invalid_yes_no_zh) printf '%s\n' '请输入 y 或 n。' ;;

        need_root_en) printf '%s\n' 'Please run with root privileges: sudo ./install.sh' ;;
        need_root_zh) printf '%s\n' '请使用管理员权限运行：sudo ./install.sh' ;;

        unknown_argument_en) printf '%s\n' 'Unsupported argument: {arg}' ;;
        unknown_argument_zh) printf '%s\n' '不支持的参数：{arg}' ;;

        unsupported_arch_en) printf '%s\n' 'Unsupported CPU architecture: {arch}. Only x86_64/amd64 and aarch64/arm64 are supported.' ;;
        unsupported_arch_zh) printf '%s\n' '不支持的 CPU 架构：{arch}。当前仅支持 x86_64/amd64 和 aarch64/arm64。' ;;

        detected_arch_en) printf '%s\n' 'Detected system architecture: {arch}, package arch: {pkg_arch}' ;;
        detected_arch_zh) printf '%s\n' '检测到系统架构：{arch}，将使用安装包架构：{pkg_arch}' ;;

        download_url_en) printf '%s\n' 'Download URL: {url}' ;;
        download_url_zh) printf '%s\n' '下载链接：{url}' ;;

        pkg_manager_unknown_en) printf '%s\n' 'Unable to detect package manager. Please install manually: {pkgs}' ;;
        pkg_manager_unknown_zh) printf '%s\n' '无法识别包管理器，请手动安装：{pkgs}' ;;

        installing_deps_en) printf '%s\n' 'Installing missing dependencies: {pkgs}' ;;
        installing_deps_zh) printf '%s\n' '正在安装缺失依赖：{pkgs}' ;;

        wget_unavailable_en) printf '%s\n' 'wget installation failed or is unavailable' ;;
        wget_unavailable_zh) printf '%s\n' 'wget 安装失败或不可用' ;;

        unzip_unavailable_en) printf '%s\n' 'unzip installation failed or is unavailable' ;;
        unzip_unavailable_zh) printf '%s\n' 'unzip 安装失败或不可用' ;;

        crontab_unavailable_en) printf '%s\n' 'crontab is unavailable. Please check if cron/cronie is installed.' ;;
        crontab_unavailable_zh) printf '%s\n' 'crontab 不可用，请检查 cron/cronie 是否安装成功' ;;

        uninstall_start_en) printf '%s\n' 'Starting one-click uninstall.' ;;
        uninstall_start_zh) printf '%s\n' '开始一键卸载。' ;;

        uninstall_confirm_prompt_en) printf '%s\n' 'Confirm uninstall xdsrun, watchdog, symlinks, and related crontab entries?' ;;
        uninstall_confirm_prompt_zh) printf '%s\n' '确认卸载 xdsrun、watchdog、软链接以及相关 crontab 记录？' ;;

        uninstall_cancelled_en) printf '%s\n' 'Uninstall cancelled.' ;;
        uninstall_cancelled_zh) printf '%s\n' '已取消卸载。' ;;

        uninstall_remove_cron_en) printf '%s\n' 'Removing watchdog crontab entries.' ;;
        uninstall_remove_cron_zh) printf '%s\n' '正在删除 watchdog 的 crontab 记录。' ;;

        uninstall_crontab_skipped_en) printf '%s\n' 'crontab is unavailable, skipping crontab cleanup.' ;;
        uninstall_crontab_skipped_zh) printf '%s\n' 'crontab 不可用，已跳过 crontab 清理。' ;;

        uninstall_crontab_done_en) printf '%s\n' 'watchdog crontab entries removed.' ;;
        uninstall_crontab_done_zh) printf '%s\n' 'watchdog 的 crontab 记录已删除。' ;;

        uninstall_remove_link_done_en) printf '%s\n' 'Removed symlink: {path}' ;;
        uninstall_remove_link_done_zh) printf '%s\n' '已删除软链接：{path}' ;;

        uninstall_remove_link_skipped_en) printf '%s\n' 'Path exists but is not a symlink, skipped: {path}' ;;
        uninstall_remove_link_skipped_zh) printf '%s\n' '路径存在但不是软链接，已跳过：{path}' ;;

        uninstall_remove_dir_done_en) printf '%s\n' 'Removed installation directory: {path}' ;;
        uninstall_remove_dir_done_zh) printf '%s\n' '已删除安装目录：{path}' ;;

        uninstall_complete_en) printf '%s\n' 'Uninstall complete.' ;;
        uninstall_complete_zh) printf '%s\n' '卸载完成。' ;;

        username_prompt_en) printf '%s\n' 'Enter Xidian campus network username:' ;;
        username_prompt_zh) printf '%s\n' '请输入西电校园网用户名:' ;;

        username_empty_en) printf '%s\n' 'Username cannot be empty.' ;;
        username_empty_zh) printf '%s\n' '用户名不能为空。' ;;

        password_prompt_en) printf '%s\n' 'Enter Xidian campus network password:' ;;
        password_prompt_zh) printf '%s\n' '请输入西电校园网密码:' ;;

        password_empty_en) printf '%s\n' 'Password cannot be empty.' ;;
        password_empty_zh) printf '%s\n' '密码不能为空。' ;;

        interval_intro_en) printf '%s\n' 'Enter watchdog execution interval:' ;;
        interval_intro_zh) printf '%s\n' '请输入 watchdog 执行间隔：' ;;

        interval_format_hint_en) printf '%s\n' '  number + time unit (m, h, d)' ;;
        interval_format_hint_zh) printf '%s\n' '  数字+时间单位（m、h、d）' ;;

        interval_unit_hint_en) printf '%s\n' '  m = minutes / h = hours / d = days' ;;
        interval_unit_hint_zh) printf '%s\n' '  m 表示分钟 / h 表示小时 / d 表示天' ;;

        interval_prompt_en) printf '%s\n' 'Execution interval [default: 5m]:' ;;
        interval_prompt_zh) printf '%s\n' '执行间隔 [默认: 5m]:' ;;

        interval_invalid_en) printf '%s\n' 'Invalid interval format. Please use a format like 5m, 2h, 1d.' ;;
        interval_invalid_zh) printf '%s\n' '执行间隔格式错误。请输入类似 5m、2h、1d 的格式。' ;;

        interval_constraints_en) printf '%s\n' 'Constraints: minutes 1-59, hours 1-23, days must be a positive integer.' ;;
        interval_constraints_zh) printf '%s\n' '限制：分钟 1-59，小时 1-23，天为正整数。' ;;

        interval_desc_minutes_en) printf '%s\n' 'every {num} minute(s)' ;;
        interval_desc_minutes_zh) printf '%s\n' '每 {num} 分钟' ;;

        interval_desc_hours_en) printf '%s\n' 'every {num} hour(s)' ;;
        interval_desc_hours_zh) printf '%s\n' '每 {num} 小时' ;;

        interval_desc_days_en) printf '%s\n' 'every {num} day(s)' ;;
        interval_desc_days_zh) printf '%s\n' '每 {num} 天' ;;

        xdsrun_exists_en) printf '%s\n' 'xdsrun already exists: {path}' ;;
        xdsrun_exists_zh) printf '%s\n' '检测到 xdsrun 已存在：{path}' ;;

        reinstall_xdsrun_prompt_en) printf '%s\n' 'Re-download and install xdsrun?' ;;
        reinstall_xdsrun_prompt_zh) printf '%s\n' '是否重新下载并安装 xdsrun？' ;;

        reinstalling_xdsrun_en) printf '%s\n' 'Will re-install xdsrun' ;;
        reinstalling_xdsrun_zh) printf '%s\n' '将重新安装 xdsrun' ;;

        skip_reinstall_xdsrun_en) printf '%s\n' 'Skipping xdsrun re-installation, ensuring it is executable' ;;
        skip_reinstall_xdsrun_zh) printf '%s\n' '跳过 xdsrun 重新安装，仅确保其具有可执行权限' ;;

        downloading_xdsrun_en) printf '%s\n' 'Downloading xdsrun: {url}' ;;
        downloading_xdsrun_zh) printf '%s\n' '下载 xdsrun：{url}' ;;

        extracting_zip_en) printf '%s\n' 'Extracting: {path}' ;;
        extracting_zip_zh) printf '%s\n' '解压：{path}' ;;

        xdsrun_not_found_after_extract_en) printf '%s\n' 'xdsrun binary not found after extraction' ;;
        xdsrun_not_found_after_extract_zh) printf '%s\n' '解压后没有找到 xdsrun 二进制程序' ;;

        xdsrun_installed_en) printf '%s\n' 'xdsrun installed to: {path}' ;;
        xdsrun_installed_zh) printf '%s\n' 'xdsrun 已安装到：{path}' ;;

        writing_watchdog_config_en) printf '%s\n' 'Writing watchdog config file: {path}' ;;
        writing_watchdog_config_zh) printf '%s\n' '写入 watchdog 配置文件：{path}' ;;

        watchdog_exists_en) printf '%s\n' 'xdsrun-watchdog already exists: {path}' ;;
        watchdog_exists_zh) printf '%s\n' '检测到 xdsrun-watchdog 已存在：{path}' ;;

        regenerate_watchdog_prompt_en) printf '%s\n' 'Re-generate xdsrun-watchdog script?' ;;
        regenerate_watchdog_prompt_zh) printf '%s\n' '是否重新生成 xdsrun-watchdog 脚本？' ;;

        regenerating_watchdog_en) printf '%s\n' 'Will re-generate xdsrun-watchdog' ;;
        regenerating_watchdog_zh) printf '%s\n' '将重新生成 xdsrun-watchdog' ;;

        skip_regenerate_watchdog_en) printf '%s\n' 'Skipping xdsrun-watchdog re-generation, ensuring it is executable' ;;
        skip_regenerate_watchdog_zh) printf '%s\n' '跳过 xdsrun-watchdog 重新生成，仅确保其具有可执行权限' ;;

        writing_watchdog_script_en) printf '%s\n' 'Writing watchdog script: {path}' ;;
        writing_watchdog_script_zh) printf '%s\n' '写入 watchdog 脚本：{path}' ;;

        cron_configuring_en) printf '%s\n' 'Configuring root crontab to run watchdog {interval}' ;;
        cron_configuring_zh) printf '%s\n' '配置 root crontab，{interval}执行一次 watchdog' ;;

        cron_configured_en) printf '%s\n' 'crontab configured: {line}' ;;
        cron_configured_zh) printf '%s\n' 'crontab 已配置：{line}' ;;

        symlink_ready_en) printf '%s\n' 'Symlink ready: {link} -> {target}' ;;
        symlink_ready_zh) printf '%s\n' '软链接已就绪：{link} -> {target}' ;;

        file_conflict_en) printf '%s\n' 'Existing file blocks symlink creation: {path}' ;;
        file_conflict_zh) printf '%s\n' '已有文件阻止创建软链接：{path}' ;;

        replace_file_prompt_en) printf '%s\n' 'Replace the existing file at {path} with a symlink?' ;;
        replace_file_prompt_zh) printf '%s\n' '是否将现有文件 {path} 替换为软链接？' ;;

        directory_conflict_en) printf '%s\n' 'Existing directory blocks symlink creation: {path}' ;;
        directory_conflict_zh) printf '%s\n' '已有目录阻止创建软链接：{path}' ;;

        symlink_skipped_en) printf '%s\n' 'Skipped symlink creation: {path}' ;;
        symlink_skipped_zh) printf '%s\n' '已跳过软链接创建：{path}' ;;

        installation_complete_en) printf '%s\n' 'Installation complete.' ;;
        installation_complete_zh) printf '%s\n' '安装完成。' ;;

        system_arch_en) printf '%s\n' 'System architecture: {arch}' ;;
        system_arch_zh) printf '%s\n' '系统架构：{arch}' ;;

        package_arch_en) printf '%s\n' 'Package architecture: {arch}' ;;
        package_arch_zh) printf '%s\n' '安装包架构：{arch}' ;;

        xdsrun_binary_en) printf '%s\n' 'xdsrun binary: {path}' ;;
        xdsrun_binary_zh) printf '%s\n' 'xdsrun 程序：{path}' ;;

        xdsrun_symlink_label_en) printf '%s\n' 'xdsrun symlink: {path}' ;;
        xdsrun_symlink_label_zh) printf '%s\n' 'xdsrun 软链接：{path}' ;;

        watchdog_script_label_en) printf '%s\n' 'watchdog script: {path}' ;;
        watchdog_script_label_zh) printf '%s\n' 'watchdog 脚本：{path}' ;;

        watchdog_symlink_label_en) printf '%s\n' 'watchdog symlink: {path}' ;;
        watchdog_symlink_label_zh) printf '%s\n' 'watchdog 软链接：{path}' ;;

        watchdog_config_label_en) printf '%s\n' 'watchdog config: {path}' ;;
        watchdog_config_label_zh) printf '%s\n' 'watchdog 配置：{path}' ;;

        log_dir_label_en) printf '%s\n' 'Log directory: {path}' ;;
        log_dir_label_zh) printf '%s\n' '日志目录：{path}' ;;

        execution_interval_label_en) printf '%s\n' 'Execution interval: {interval}' ;;
        execution_interval_label_zh) printf '%s\n' '执行间隔：{interval}' ;;

        manual_test_en) printf '%s\n' 'Manual test:' ;;
        manual_test_zh) printf '%s\n' '可手动测试：' ;;

        view_root_crontab_en) printf '%s\n' 'View root crontab:' ;;
        view_root_crontab_zh) printf '%s\n' '查看 root crontab：' ;;

        config_header_en) printf '%s\n' '# xdsrun-watchdog configuration' ;;
        config_header_zh) printf '%s\n' '# xdsrun-watchdog 配置文件' ;;

        config_generated_by_en) printf '%s\n' '# Generated by install.sh' ;;
        config_generated_by_zh) printf '%s\n' '# 由 install.sh 生成' ;;

        config_ping_section_en) printf '%s\n' '# ====== PING configuration ======' ;;
        config_ping_section_zh) printf '%s\n' '# ====== PING 配置 ======' ;;

        config_login_section_en) printf '%s\n' '# ====== Login configuration ======' ;;
        config_login_section_zh) printf '%s\n' '# ====== 登录配置 ======' ;;

        config_log_section_en) printf '%s\n' '# ====== LOG configuration ======' ;;
        config_log_section_zh) printf '%s\n' '# ====== LOG 配置 ======' ;;

        watchdog_comment_en) printf '%s\n' '# Auto-detect network status, login via xdsrun when offline' ;;
        watchdog_comment_zh) printf '%s\n' '# 自动检测网络，断网时调用 xdsrun 登录' ;;

        watchdog_paths_section_en) printf '%s\n' '# ====== Built-in path config ======' ;;
        watchdog_paths_section_zh) printf '%s\n' '# ====== 脚本内置路径配置 ======' ;;

        watchdog_load_config_en) printf '%s\n' '# ====== Load config file ======' ;;
        watchdog_load_config_zh) printf '%s\n' '# ====== 加载配置文件 ======' ;;

        watchdog_basic_checks_en) printf '%s\n' '# ====== Basic checks ======' ;;
        watchdog_basic_checks_zh) printf '%s\n' '# ====== 基础检查 ======' ;;

        watchdog_network_check_en) printf '%s\n' '# ====== Check network connectivity ======' ;;
        watchdog_network_check_zh) printf '%s\n' '# ====== 检测网络是否在线 ======' ;;

        watchdog_log_section_en) printf '%s\n' '# ====== LOG configuration ======' ;;
        watchdog_log_section_zh) printf '%s\n' '# ====== LOG 配置 ======' ;;

        watchdog_prepare_log_en) printf '%s\n' '# ====== Prepare log ======' ;;
        watchdog_prepare_log_zh) printf '%s\n' '# ====== 日志准备 ======' ;;

        watchdog_login_en) printf '%s\n' '# ====== Login to Xidian campus network ======' ;;
        watchdog_login_zh) printf '%s\n' '# ====== 登录西电校园网 ======' ;;

        watchdog_config_missing_en) printf '%s\n' 'Config file not found: \${CONFIG_FILE}' ;;
        watchdog_config_missing_zh) printf '%s\n' '配置文件不存在：\${CONFIG_FILE}' ;;

        watchdog_ping_target_empty_en) printf '%s\n' 'PING_TARGET is empty, please check config: \${CONFIG_FILE}' ;;
        watchdog_ping_target_empty_zh) printf '%s\n' 'PING_TARGET 为空，请检查配置文件：\${CONFIG_FILE}' ;;

        watchdog_ping_count_empty_en) printf '%s\n' 'PING_COUNT is empty, please check config: \${CONFIG_FILE}' ;;
        watchdog_ping_count_empty_zh) printf '%s\n' 'PING_COUNT 为空，请检查配置文件：\${CONFIG_FILE}' ;;

        watchdog_ping_timeout_empty_en) printf '%s\n' 'PING_TIMEOUT is empty, please check config: \${CONFIG_FILE}' ;;
        watchdog_ping_timeout_empty_zh) printf '%s\n' 'PING_TIMEOUT 为空，请检查配置文件：\${CONFIG_FILE}' ;;

        watchdog_username_password_empty_en) printf '%s\n' 'USERNAME or PASSWORD is empty, please check config: \${CONFIG_FILE}' ;;
        watchdog_username_password_empty_zh) printf '%s\n' 'USERNAME 或 PASSWORD 为空，请检查配置文件：\${CONFIG_FILE}' ;;

        watchdog_log_dir_empty_en) printf '%s\n' 'LOG_DIR is empty, please check config: \${CONFIG_FILE}' ;;
        watchdog_log_dir_empty_zh) printf '%s\n' 'LOG_DIR 为空，请检查配置文件：\${CONFIG_FILE}' ;;

        watchdog_bin_missing_en) printf '%s\n' 'xdsrun does not exist or is not executable: \${XDSRUN_BIN}' ;;
        watchdog_bin_missing_zh) printf '%s\n' 'xdsrun 不存在或不可执行：\${XDSRUN_BIN}' ;;

        *)
            printf '%s\n' "$1"
            ;;
    esac
}

render_msg() {
    local text="$(
        msg "$1"
    )"
    shift

    local kv key value
    for kv in "$@"; do
        key="${kv%%=*}"
        value="${kv#*=}"
        text="${text//\{$key\}/$value}"
    done

    printf '%s' "${text}"
}

# ============================================================
# Utility functions
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

log_msg() {
    log "$(render_msg "$@")"
}

err_msg() {
    err "$(render_msg "$@")"
}

warn_msg() {
    warn "$(render_msg "$@")"
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
                printf '%s\n' "$(render_msg invalid_yes_no)"
                ;;
        esac
    done
}

ensure_bin_link() {
    local target_path="$1"
    local link_path="$2"

    mkdir -p "$(dirname "${link_path}")"

    if [ -d "${link_path}" ] && [ ! -L "${link_path}" ]; then
        warn_msg directory_conflict path="${link_path}"
        return
    fi

    if [ -e "${link_path}" ] && [ ! -L "${link_path}" ]; then
        warn_msg file_conflict path="${link_path}"

        if ! ask_yes_no "$(render_msg replace_file_prompt path="${link_path}")"; then
            warn_msg symlink_skipped path="${link_path}"
            return
        fi
    fi

    ln -sfn "${target_path}" "${link_path}"
    log_msg symlink_ready link="${link_path}" target="${target_path}"
}

parse_args() {
    ACTION="install"

    local arg
    for arg in "$@"; do
        case "${arg}" in
            -u|--uninstall)
                ACTION="uninstall"
                ;;
            *)
                err_msg unknown_argument arg="${arg}"
                ;;
        esac
    done
}

remove_watchdog_cron() {
    if ! command_exists crontab; then
        warn_msg uninstall_crontab_skipped
        return
    fi

    log_msg uninstall_remove_cron

    local current_cron
    current_cron="$(mktemp /tmp/xdsrun_cron_remove.XXXXXX)"

    crontab -l 2>/dev/null > "${current_cron}" || true

    sed -i.bak "/${CRON_MARK_BEGIN}/,/${CRON_MARK_END}/d" "${current_cron}"

    grep -v -F "${WATCHDOG_SCRIPT}" "${current_cron}" > "${current_cron}.new" || true
    mv "${current_cron}.new" "${current_cron}"

    crontab "${current_cron}"

    rm -f "${current_cron}" "${current_cron}.bak"

    log_msg uninstall_crontab_done
}

remove_managed_link() {
    local link_path="$1"

    if [ -L "${link_path}" ]; then
        rm -f "${link_path}"
        log_msg uninstall_remove_link_done path="${link_path}"
    elif [ -e "${link_path}" ]; then
        warn_msg uninstall_remove_link_skipped path="${link_path}"
    fi
}

uninstall_all() {
    log_msg uninstall_start

    if ! ask_yes_no "$(render_msg uninstall_confirm_prompt)"; then
        log_msg uninstall_cancelled
        return
    fi

    remove_watchdog_cron
    remove_managed_link "${XDSRUN_BIN_LINK}"
    remove_managed_link "${WATCHDOG_BIN_LINK}"

    if [ -e "${XDSRUN_DIR}" ]; then
        rm -rf "${XDSRUN_DIR}"
        log_msg uninstall_remove_dir_done path="${XDSRUN_DIR}"
    fi

    log_msg uninstall_complete
}

select_language() {
    local lang

    echo "========================================"
    echo "  xdsrun installer"
    echo "========================================"
    echo
    echo "Select language:"
    echo "  1) English"
    echo "  2) 简体中文"
    echo
    read -r -p "Enter choice [1-2] (default: 2): " lang

    case "${lang}" in
        1)
            LANG_CODE="en"
            ;;
        2|"")
            LANG_CODE="zh"
            ;;
        *)
            echo "Invalid choice, defaulting to Chinese"
            LANG_CODE="zh"
            ;;
    esac
}

need_root() {
    if [ "${EUID}" -ne 0 ]; then
        err_msg need_root
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
            err_msg unsupported_arch arch="${ARCH}"
            ;;
    esac

    ZIP_FILE="${TMP_DIR}/xdsrun_${XDSRUN_VERSION}_linux_${XDSRUN_PKG_ARCH}.zip"
    XDSRUN_URL="https://github.com/NanCunChild/xdsrun-login/releases/download/v${XDSRUN_VERSION}/xdsrun_${XDSRUN_VERSION}_linux_${XDSRUN_PKG_ARCH}.zip"

    log_msg detected_arch arch="${ARCH}" pkg_arch="${XDSRUN_PKG_ARCH}"
    log_msg download_url url="${XDSRUN_URL}"
}

install_packages() {
    local pkgs=("$@")
    local pm
    pm="$(detect_pkg_manager)"

    if [ "${pm}" = "unknown" ]; then
        err_msg pkg_manager_unknown pkgs="${pkgs[*]}"
    fi

    log_msg installing_deps pkgs="${pkgs[*]}"

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

    command_exists wget || err_msg wget_unavailable
    command_exists unzip || err_msg unzip_unavailable
    command_exists crontab || err_msg crontab_unavailable
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
            INTERVAL_DESC="$(render_msg interval_desc_minutes num="${num}")"
            ;;
        h)
            if [ "${num}" -gt 23 ]; then
                return 1
            fi
            CRON_EXPR="0 */${num} * * *"
            INTERVAL_DESC="$(render_msg interval_desc_hours num="${num}")"
            ;;
        d)
            CRON_EXPR="0 0 */${num} * *"
            INTERVAL_DESC="$(render_msg interval_desc_days num="${num}")"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

prompt_config() {
    echo
    read -r -p "$(render_msg username_prompt) " INPUT_USERNAME

    while [ -z "${INPUT_USERNAME}" ]; do
        printf '%s\n' "$(render_msg username_empty)"
        read -r -p "$(render_msg username_prompt) " INPUT_USERNAME
    done

    read -r -s -p "$(render_msg password_prompt) " INPUT_PASSWORD
    echo

    while [ -z "${INPUT_PASSWORD}" ]; do
        printf '%s\n' "$(render_msg password_empty)"
        read -r -s -p "$(render_msg password_prompt) " INPUT_PASSWORD
        echo
    done

    echo
    printf '%s\n' "$(render_msg interval_intro)"
    printf '%s\n' "$(render_msg interval_format_hint)"
    printf '%s\n' "$(render_msg interval_unit_hint)"
    read -r -p "$(render_msg interval_prompt) " INPUT_INTERVAL

    if [ -z "${INPUT_INTERVAL}" ]; then
        INPUT_INTERVAL="5m"
    fi

    while ! parse_interval_to_cron "${INPUT_INTERVAL}"; do
        printf '%s\n' "$(render_msg interval_invalid)"
        printf '%s\n' "$(render_msg interval_constraints)"
        read -r -p "$(render_msg interval_prompt) " INPUT_INTERVAL

        if [ -z "${INPUT_INTERVAL}" ]; then
            INPUT_INTERVAL="5m"
        fi
    done
}

install_xdsrun_bin() {
    mkdir -p "${XDSRUN_DIR}"

    if [ -f "${XDSRUN_BIN}" ]; then
        log_msg xdsrun_exists path="${XDSRUN_BIN}"

        if ask_yes_no "$(render_msg reinstall_xdsrun_prompt)"; then
            log_msg reinstalling_xdsrun
        else
            log_msg skip_reinstall_xdsrun
            chmod +x "${XDSRUN_BIN}"
            ensure_bin_link "${XDSRUN_BIN}" "${XDSRUN_BIN_LINK}"
            return
        fi
    fi

    log_msg downloading_xdsrun url="${XDSRUN_URL}"
    wget -O "${ZIP_FILE}" "${XDSRUN_URL}"

    local extract_dir
    extract_dir="$(mktemp -d /tmp/xdsrun_extract.XXXXXX)"

    log_msg extracting_zip path="${ZIP_FILE}"
    unzip -o "${ZIP_FILE}" -d "${extract_dir}" >/dev/null

    if [ ! -f "${extract_dir}/xdsrun" ]; then
        rm -rf "${extract_dir}"
        err_msg xdsrun_not_found_after_extract
    fi

    local staged_bin
    staged_bin="${XDSRUN_DIR}/.xdsrun.new.$$"

    rm -f "${staged_bin}"
    cp "${extract_dir}/xdsrun" "${staged_bin}"
    chmod +x "${staged_bin}"
    mv -f "${staged_bin}" "${XDSRUN_BIN}"

    rm -rf "${extract_dir}"

    log_msg xdsrun_installed path="${XDSRUN_BIN}"
    ensure_bin_link "${XDSRUN_BIN}" "${XDSRUN_BIN_LINK}"
}

write_watchdog_config() {
    log_msg writing_watchdog_config path="${WATCHDOG_CONFIG}"

    cat > "${WATCHDOG_CONFIG}" <<EOF
$(render_msg config_header)
$(render_msg config_generated_by)

$(render_msg config_ping_section)
PING_TARGET="223.5.5.5"
PING_COUNT=3
PING_TIMEOUT=3

$(render_msg config_login_section)
USERNAME="${INPUT_USERNAME}"
PASSWORD="${INPUT_PASSWORD}"

$(render_msg config_log_section)
LOG_DIR="${XDSRUN_DIR}/log"
EOF

    chmod 600 "${WATCHDOG_CONFIG}"
}

write_watchdog_script() {
    if [ -f "${WATCHDOG_SCRIPT}" ]; then
        log_msg watchdog_exists path="${WATCHDOG_SCRIPT}"

        if ask_yes_no "$(render_msg regenerate_watchdog_prompt)"; then
            log_msg regenerating_watchdog
            rm -f "${WATCHDOG_SCRIPT}"
        else
            log_msg skip_regenerate_watchdog
            chmod +x "${WATCHDOG_SCRIPT}"
            ensure_bin_link "${WATCHDOG_SCRIPT}" "${WATCHDOG_BIN_LINK}"
            return
        fi
    fi

    log_msg writing_watchdog_script path="${WATCHDOG_SCRIPT}"

    cat > "${WATCHDOG_SCRIPT}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# xdsrun-watchdog
$(render_msg watchdog_comment)
# ============================================================

$(render_msg watchdog_paths_section)
XDSRUN_BIN="${XDSRUN_BIN}"
CONFIG_FILE="${WATCHDOG_CONFIG}"

$(render_msg watchdog_load_config)
if [ -f "\${CONFIG_FILE}" ]; then
    # shellcheck disable=SC1090
    source "\${CONFIG_FILE}"
else
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] $(render_msg watchdog_config_missing)" >&2
    exit 1
fi

$(render_msg watchdog_basic_checks)
if [ -z "\${PING_TARGET:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] $(render_msg watchdog_ping_target_empty)" >&2
    exit 1
fi

if [ -z "\${PING_COUNT:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] $(render_msg watchdog_ping_count_empty)" >&2
    exit 1
fi

if [ -z "\${PING_TIMEOUT:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] $(render_msg watchdog_ping_timeout_empty)" >&2
    exit 1
fi

if [ -z "\${USERNAME:-}" ] || [ -z "\${PASSWORD:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] $(render_msg watchdog_username_password_empty)" >&2
    exit 1
fi

if [ -z "\${LOG_DIR:-}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] $(render_msg watchdog_log_dir_empty)" >&2
    exit 1
fi

if [ ! -x "\${XDSRUN_BIN}" ]; then
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] $(render_msg watchdog_bin_missing)" >&2
    exit 1
fi

$(render_msg watchdog_network_check)
if ping -c "\${PING_COUNT}" -W "\${PING_TIMEOUT}" "\${PING_TARGET}" >/dev/null 2>&1; then
    exit 0
fi

$(render_msg watchdog_log_section)
MONTH_STR="\$(date '+%Y-%m')"
LOGFILE="\${LOG_DIR}/xdsrun_\${MONTH_STR}.log"

$(render_msg watchdog_prepare_log)
mkdir -p "\${LOG_DIR}"
timestamp="\$(date '+%Y-%m-%d %H:%M:%S')"

$(render_msg watchdog_login)
output="\$("\${XDSRUN_BIN}" -u "\${USERNAME}" -p "\${PASSWORD}" 2>&1)"
echo "[\${timestamp}] \${output}" >> "\${LOGFILE}"
EOF

    chmod +x "${WATCHDOG_SCRIPT}"
    ensure_bin_link "${WATCHDOG_SCRIPT}" "${WATCHDOG_BIN_LINK}"
}

install_cron() {
    log_msg cron_configuring interval="${INTERVAL_DESC}"

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

    log_msg cron_configured line="${cron_line}"
}

main() {
    parse_args "$@"

    if [ "${ACTION}" = "install" ]; then
        select_language
    fi

    need_root

    if [ "${ACTION}" = "uninstall" ]; then
        uninstall_all
        return
    fi

    detect_arch_and_set_url
    ensure_deps
    enable_cron_service

    install_xdsrun_bin
    write_watchdog_script

    prompt_config

    write_watchdog_config
    install_cron

    echo
    log_msg installation_complete
    printf '%s\n' "$(render_msg system_arch arch="${ARCH}")"
    printf '%s\n' "$(render_msg package_arch arch="${XDSRUN_PKG_ARCH}")"
    printf '%s\n' "$(render_msg download_url url="${XDSRUN_URL}")"
    printf '%s\n' "$(render_msg xdsrun_binary path="${XDSRUN_BIN}")"
    printf '%s\n' "$(render_msg xdsrun_symlink_label path="${XDSRUN_BIN_LINK}")"
    printf '%s\n' "$(render_msg watchdog_script_label path="${WATCHDOG_SCRIPT}")"
    printf '%s\n' "$(render_msg watchdog_symlink_label path="${WATCHDOG_BIN_LINK}")"
    printf '%s\n' "$(render_msg watchdog_config_label path="${WATCHDOG_CONFIG}")"
    printf '%s\n' "$(render_msg log_dir_label path="${XDSRUN_DIR}/log")"
    printf '%s\n' "$(render_msg execution_interval_label interval="${INTERVAL_DESC}")"
    echo
    printf '%s\n' "$(render_msg manual_test)"
    echo "  sudo ${WATCHDOG_SCRIPT}"
    echo
    printf '%s\n' "$(render_msg view_root_crontab)"
    echo "  sudo crontab -l"
}

main "$@"
