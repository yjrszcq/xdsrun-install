# xdsrun 自动安装脚本

本项目用于在 Linux 系统上自动安装 [`xdsrun`](https://github.com/NanCunChild/xdsrun-login) 并配置专用的断网自动重连脚本。

## 一键安装命令

```
sudo bash -c "$(curl -fsSL 'https://raw.githubusercontent.com/yjrszcq/xdsrun-install/refs/heads/main/install.sh')"
```

## 功能说明

`install.sh` 会完成以下工作：

1. 检查是否使用管理员权限运行；
2. 检查并安装必要依赖：
   - `wget`
   - `unzip`
   - `crontab`
3. 下载 `xdsrun` 压缩包；
4. 解压得到 `xdsrun` 二进制程序；
5. 安装到指定目录，默认：

   ```bash
   /opt/xdsrun
   ```

6. 生成 watchdog 脚本：

   ```bash
   /opt/xdsrun/xdsrun-watchdog
   ```

7. 生成 watchdog 配置文件：

   ```bash
   /opt/xdsrun/xdsrun-watchdog.conf
   ```

8. 配置 root 用户的 `crontab`，定时执行 watchdog。

---

## 文件结构

安装完成后，默认目录结构如下：

```text
/opt/xdsrun/
├── xdsrun
├── xdsrun-watchdog
├── xdsrun-watchdog.conf
└── log/
    └── xdsrun_YYYY-MM.log
```

说明：

| 文件                     | 作用            |
| ---------------------- | ------------- |
| `xdsrun`               | 校园网登录程序       |
| `xdsrun-watchdog`      | 网络检测与自动登录脚本   |
| `xdsrun-watchdog.conf` | watchdog 配置文件 |
| `log/`                 | 登录日志目录        |

---

## 使用方法

### 1. 保存脚本

将安装脚本保存为：

```bash
install.sh
```

### 2. 添加执行权限

```bash
chmod +x install.sh
```

### 3. 使用管理员权限运行

```bash
sudo ./install.sh
```

---

## 安装过程中的交互输入

运行脚本后，需要输入以下内容。

### 1. 西电校园网用户名

```text
请输入西电校园网用户名:
```

### 2. 西电校园网密码

```text
请输入西电校园网密码:
```

密码输入时不会显示在终端中。

### 3. watchdog 执行间隔

支持使用 `m`、`h`、`d` 表示分钟、小时、天。

示例：

| 输入   | 含义         | crontab 表达式   |
| ---- | ---------- | ------------- |
| `5m` | 每 5 分钟执行一次 | `*/5 * * * *` |
| `2h` | 每 2 小时执行一次 | `0 */2 * * *` |
| `1d` | 每 1 天执行一次  | `0 0 */1 * *` |

例如：

```text
执行间隔: 5m
```

表示每 5 分钟执行一次 `xdsrun-watchdog`。

---

## 配置文件说明

配置文件默认路径为：

```bash
/opt/xdsrun/xdsrun-watchdog.conf
```

默认内容类似：

```bash
# xdsrun-watchdog 配置文件
# 由 install.sh 生成

# ====== PING 配置 ======
PING_TARGET="www.baidu.com"
PING_COUNT=3
PING_TIMEOUT=3

# ====== 登录配置 ======
USERNAME="your_username"
PASSWORD="your_password"

# ====== LOG 配置 ======
LOG_DIR="/opt/xdsrun/log"
```

### 配置项说明

| 配置项            | 说明                  | 默认值               |
| -------------- | ------------------- | ----------------- |
| `PING_TARGET`  | 用于检测网络是否在线的目标地址     | `www.baidu.com`   |
| `PING_COUNT`   | ping 包数量            | `3`               |
| `PING_TIMEOUT` | 每个 ping 包等待超时时间，单位秒 | `3`               |
| `USERNAME`     | 西电校园网登录用户名        | 安装时输入             |
| `PASSWORD`     | 西电校园网登录密码         | 安装时输入             |
| `LOG_DIR`      | 日志目录                | `/opt/xdsrun/log` |

---

## watchdog 工作流程

`xdsrun-watchdog` 每次被执行时，会执行以下流程：

```text
加载配置文件
  ↓
检查必要配置是否为空
  ↓
检查 xdsrun 是否存在且可执行
  ↓
ping PING_TARGET
  ↓
如果 ping 成功：
    认为网络在线，直接退出
  ↓
如果 ping 失败：
    执行 xdsrun 登录
  ↓
将登录输出写入日志
```

登录命令形式为：

```bash
/opt/xdsrun/xdsrun -u "$USERNAME" -p "$PASSWORD"
```

---

## 日志说明

日志目录默认是：

```bash
/opt/xdsrun/log
```

日志文件按月份生成，例如：

```bash
/opt/xdsrun/log/xdsrun_2026-04.log
```

查看当月日志：

```bash
sudo cat /opt/xdsrun/log/xdsrun_$(date '+%Y-%m').log
```

实时查看日志：

```bash
sudo tail -f /opt/xdsrun/log/xdsrun_$(date '+%Y-%m').log
```

---

## 查看 crontab 配置

安装完成后，可以查看 root 用户的 crontab：

```bash
sudo crontab -l
```

你会看到类似内容：

```cron
# >>> xdsrun-watchdog cron >>>
*/5 * * * * /opt/xdsrun/xdsrun-watchdog >/dev/null 2>&1
# <<< xdsrun-watchdog cron <<<
```

这里表示每 5 分钟执行一次 watchdog。

---

## 修改执行间隔

### 方法一：重新运行安装脚本

```bash
sudo ./install.sh
```

重新输入执行间隔即可。

脚本会自动删除旧的 `xdsrun-watchdog` crontab 记录，然后写入新的记录，不会重复追加多行。

### 方法二：手动编辑 crontab

```bash
sudo crontab -e
```

例如把：

```cron
*/5 * * * * /opt/xdsrun/xdsrun-watchdog >/dev/null 2>&1
```

改成：

```cron
0 */2 * * * /opt/xdsrun/xdsrun-watchdog >/dev/null 2>&1
```

表示每 2 小时执行一次。

---

## 修改账号、密码或 ping 配置

直接编辑配置文件：

```bash
sudo nano /opt/xdsrun/xdsrun-watchdog.conf
```

例如修改账号密码：

```bash
USERNAME="new_username"
PASSWORD="new_password"
```

例如修改 ping 目标：

```bash
PING_TARGET="223.5.5.5"
```

修改完成后不需要重启服务，下一次 watchdog 被 crontab 调用时会自动读取新配置。

---

## 手动测试 watchdog

可以直接执行：

```bash
sudo /opt/xdsrun/xdsrun-watchdog
```

如果当前网络正常，脚本会直接退出，不会输出内容。

如果网络不通，它会尝试调用 `xdsrun` 登录，并将结果写入日志文件。

---

## 重复运行安装脚本的行为

`install.sh` 可以重复执行。

### 如果 xdsrun 已存在

如果检测到：

```bash
/opt/xdsrun/xdsrun
```

已经存在，脚本会询问：

```text
是否重新下载并安装 xdsrun？ [y/N]:
```

选择：

| 输入        | 行为                    |
| --------- | --------------------- |
| `y`       | 删除旧的 `xdsrun`，重新下载并安装 |
| `n` 或直接回车 | 跳过下载，只确保其具有可执行权限      |

### 如果 xdsrun-watchdog 已存在

如果检测到：

```bash
/opt/xdsrun/xdsrun-watchdog
```

已经存在，脚本会询问：

```text
是否重新生成 xdsrun-watchdog 脚本？ [y/N]:
```

选择：

| 输入        | 行为               |
| --------- | ---------------- |
| `y`       | 删除旧脚本，重新生成       |
| `n` 或直接回车 | 跳过生成，只确保其具有可执行权限 |

### crontab 处理

脚本会删除旧的 watchdog 定时任务，再写入新的定时任务。

它会清理：

1. 由以下标记包围的旧配置块：

   ```cron
   # >>> xdsrun-watchdog cron >>>
   ...
   # <<< xdsrun-watchdog cron <<<
   ```

2. 直接包含 watchdog 路径的旧 crontab 行：

   ```cron
   /opt/xdsrun/xdsrun-watchdog
   ```

因此一般不会产生重复的定时任务。

---

## 卸载方法

如果需要卸载，可以按以下步骤操作。

### 1. 删除 crontab 任务

编辑 root crontab：

```bash
sudo crontab -e
```

删除以下内容：

```cron
# >>> xdsrun-watchdog cron >>>
*/5 * * * * /opt/xdsrun/xdsrun-watchdog >/dev/null 2>&1
# <<< xdsrun-watchdog cron <<<
```

或者删除所有包含以下内容的行：

```bash
/opt/xdsrun/xdsrun-watchdog
```

### 2. 删除安装目录

```bash
sudo rm -rf /opt/xdsrun
```

---

## 常见问题

### 1. 为什么要用 sudo 运行？

因为脚本需要写入：

```bash
/opt/xdsrun
```

并且需要修改 root 用户的 crontab。

所以需要管理员权限。

---

### 2. 为什么配置文件权限是 600？

配置文件中包含明文密码：

```bash
PASSWORD="..."
```

所以脚本会设置：

```bash
chmod 600 /opt/xdsrun/xdsrun-watchdog.conf
```

这样只有 root 用户可以读取和修改。

---

### 3. 为什么网络正常时手动执行没有输出？

这是正常现象。

watchdog 的逻辑是：

```text
ping 成功 → 网络在线 → 直接退出
```

只有网络不通并尝试登录时，才会写日志。

---

### 4. 为什么使用 [www.baidu.com](http://www.baidu.com) 作为默认 ping 目标？

因为这是一个默认的网络连通性检测目标。

如果你的网络环境中无法访问该地址，可以修改配置文件：

```bash
sudo nano /opt/xdsrun/xdsrun-watchdog.conf
```

改成其他地址，例如：

```bash
PING_TARGET="223.5.5.5"
```

---

### 5. 支持哪些 Linux 发行版？

脚本会尝试识别以下包管理器：

```text
apt-get
dnf
yum
pacman
zypper
```

理论上可支持常见 Debian、Ubuntu、CentOS、Fedora、Arch、openSUSE 等系统。

如果系统包管理器不在上述范围内，需要手动安装依赖：

```bash
wget
unzip
cron 或 cronie
```

---

### 6. 如何修改安装目录？

编辑 `install.sh` 顶部配置：

```bash
XDSRUN_DIR="/opt/xdsrun"
```

例如改成：

```bash
XDSRUN_DIR="/usr/local/xdsrun"
```

然后重新运行：

```bash
sudo ./install.sh
```

生成的 `xdsrun-watchdog`、配置文件路径、crontab 路径都会跟随该配置变化。

---

## 注意事项

1. `xdsrun-watchdog.conf` 中保存了明文密码，请不要随意分享该文件；
2. 如果你手动修改了安装目录，请重新运行安装脚本；
3. 如果修改了 crontab 执行间隔，建议使用 `sudo crontab -l` 检查是否生效；
4. 如果 watchdog 一直没有日志，可能是因为网络一直正常，脚本 ping 成功后直接退出；
5. 如果日志中出现登录失败，请检查账号、密码以及 `xdsrun` 是否可正常使用。

## 致谢

本项目中的 `xdsrun` 程序来自 [NanCunChild/xdsrun-login](https://github.com/NanCunChild/xdsrun-login)。

感谢原作者开源的 `xdsrun-login` 项目。

本仓库仅在此基础上提供 Linux 下的自动安装、配置文件生成、watchdog 网络检测以及 crontab 定时执行等辅助脚本。
