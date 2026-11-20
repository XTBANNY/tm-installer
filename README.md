# TraffMonetizer Linux Installer

一键部署脚本，在 Linux 服务器上安装 [TraffMonetizer](https://traffmonetizer.io/) 流量共享客户端。

> **注意**: 由于部分 VPS 的 Docker 环境存在 seccomp 限制（如 Proxmox VE kernel），容器无法运行。本方案采用**二进制直接安装**，兼容 **x86_64/amd64** 和 **ARM64/aarch64** 架构。

> **2026-11 重要更新**：官方域名已迁移至 `traffmonetizer.io`，旧域名 `traffmonetizer.com` 已停止解析。本仓库二进制已更新为官方 `cli_v2`（2026-11-10 版）。**旧版本客户端会一直 `connecting → disconnected` 且无收益**，详见 [下方说明](#2026-11-域名迁移与升级)。

## 使用方法

### 一键安装

```bash
curl -sSL https://raw.githubusercontent.com/XTBANNY/tm-installer/main/install.sh | sudo bash -s -- --token YOUR_TOKEN --device DEVICE_NAME
```

或者先下载再执行：

```bash
curl -sSL -o install.sh https://raw.githubusercontent.com/XTBANNY/tm-installer/main/install.sh
sudo bash install.sh --token YOUR_TOKEN --device DEVICE_NAME
```

### 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `--token` | 是 | 你的 TraffMonetizer 设备 Token（域名迁移后保持不变，无需重新获取） |
| `--device` | 是 | 设备名称（可在 Dashboard 识别） |
| `-h` | 否 | 显示帮助信息 |

### 示例

```bash
sudo bash install.sh --token YOUR_TOKEN --device my-vps
```

Token 获取方式：登录 [app.traffmonetizer.io](https://app.traffmonetizer.io) → F12 → Application → Local Storage → `https://app.traffmonetizer.io` → 复制 `authToken`。

## 2026-11 域名迁移与升级

### 发生了什么

- **2026-11-02**：旧域名 `traffmonetizer.com` 被注册商置为 `clientHold`（暂停解析），DNS 一并失效。这不是域名到期，官方随后将网站、Dashboard 和 API 全部迁至 `traffmonetizer.io`。
- **2026-11-03**：官方发布新版客户端 `cli_v2`（Docker 镜像 `traffmonetizer/cli_v2`）。
- 账户余额、设备记录、推荐关系、Token **均保持不变**，无需重新注册或换 Token。

### 为什么旧客户端会掉线

旧版二进制（2026-06 及更早）内嵌的调度服务器域名是 `blnc.traffmonetizer.com`，该域名目前已无法解析。症状：

```
Status: [any ip] - connecting
Status: [any ip] - disconnected
Status: [any ip] - connecting
Status: [any ip] - disconnected
```

无限循环，`ss -tn | grep ':769'` 查不到连接，后台设备离线、无收益。**这不是 Token 失效**——用同一个 Token 跑新版客户端可立即 `connected`。

### 如何升级

重新跑一遍一键安装命令即可。脚本会自动下载本仓库的最新二进制并重启服务：

```bash
curl -sSL https://raw.githubusercontent.com/XTBANNY/tm-installer/main/install.sh | sudo bash -s -- --token YOUR_TOKEN --device DEVICE_NAME
```

升级后验证：

```bash
systemctl status traffmonetizer
journalctl -u traffmonetizer -f        # 应显示 Status: [any ip] - connected
ss -tn | grep ':769'                   # 应看到 ESTAB 连接，端口 769
```

> 若日志仍为 `disconnected`，先确认二进制版本：新版大小约 **2.8 MB（amd64）/ 2.3 MB（arm64）**，旧版约 2.7 MB / 2.2 MB。可用 `grep -aoE 'blnc\.traffmonetizer\.com|c1\.traffmonetizer\.to' /usr/local/bin/traffmonetizer` 判断：命中 `blnc.traffmonetizer.com` 即为旧版。

## 安装后

安装完成后会自动：

1. 下载最新二进制文件到 `/usr/local/bin/traffmonetizer`
2. 创建 systemd 服务 `traffmonetizer.service`
3. 设置开机自启
4. 启动服务并验证运行状态

### 常用命令

```bash
# 查看服务状态
systemctl status traffmonetizer

# 查看实时日志
journalctl -u traffmonetizer -f

# 手动重启
systemctl restart traffmonetizer

# 手动停止
systemctl stop traffmonetizer
```

### 卸载

```bash
systemctl stop traffmonetizer
systemctl disable traffmonetizer
rm -f /usr/local/bin/traffmonetizer /etc/systemd/system/traffmonetizer.service
systemctl daemon-reload
```

## 系统要求

- OS: 带 **systemd** 的 Linux 发行版（Debian/Ubuntu/CentOS/Fedora 等）
- 架构: x86_64/amd64 或 ARM64/aarch64
- 权限: root (或 sudo)
- 网络: 需要访问互联网下载二进制文件

> **Alpine Linux 注意**：Alpine 使用 OpenRC 而非 systemd，本脚本创建的 systemd 服务不会生效。需要在 Alpine 上部署时，请改用 OpenRC 服务脚本（`/etc/init.d/traffmonetizer` + `rc-update add ... default`），并加上 `command_background="yes"`（OpenRC 0.55 必需）。同理，无 init 的容器（Android/DroidSpaces 等）需改用 `/etc/profile.d/` 自启钩子。二进制本身是 musl 兼容的，可直接使用。

## 故障排查

### 日志一直 connecting → disconnected

这是旧版客户端连接已失效的调度域名所致，**不是 Token 问题**。按 [2026-11 域名迁移与升级](#2026-11-域名迁移与升级) 重新升级即可。可用以下命令确认：

```bash
grep -aoE 'blnc\.traffmonetizer\.com|c1\.traffmonetizer\.to' /usr/local/bin/traffmonetizer
getent hosts blnc.traffmonetizer.com    # 无输出 = 该域名已停解析
ss -tn | grep ':769'                    # 无输出 = 未连接到网络
```

### 下载失败

如果你的服务器在中国大陆，可能无法访问 GitHub releases。解决方法：

1. **手动下载二进制**：从 [Releases](https://github.com/XTBANNY/tm-installer/releases/latest) 下载 `traffmonetizer` 文件
2. **上传到服务器**：
   ```bash
   scp traffmonetizer root@your-server:/tmp/
   ```
3. **手动安装**：
   ```bash
   ssh root@your-server
   cp /tmp/traffmonetizer /usr/local/bin/
   chmod +x /usr/local/bin/traffmonetizer
   # 然后编辑 /etc/systemd/system/traffmonetizer.service 并启动
   ```

> 提示：`raw.githubusercontent.com` 在部分网络环境不可达，但 `github.com/.../releases/latest/download/...` 通常可达，本脚本已包含镜像回退。

### 服务启动失败

```bash
journalctl -u traffmonetizer -n 50 --no-pager
```

检查 Token 是否正确，网络连接是否正常。

## 技术说明

本脚本通过 systemd 管理服务而非 Docker，优势：

- 兼容所有带 systemd 的 Linux 发行版
- 无需 Docker 环境
- 避免 seccomp/AppArmor 限制
- 资源占用极低（约 1–2 MB 内存）
- 系统崩溃后自动重启

二进制来自官方 `traffmonetizer/cli_v2` 镜像（2026-11-10 版），抽取为原生可执行文件，参数与原版一致，不依赖 Docker 运行时。

## License

MIT
