# TraffMonetizer Linux Installer

一键部署脚本，在 Linux 服务器上安装 [TraffMonetizer](https://traffmonetizer.com/) 流量共享客户端。

> **注意**: 由于部分 VPS 的 Docker 环境存在 seccomp 限制（如 Proxmox VE kernel），容器无法运行。本方案采用**二进制直接安装**，兼容 **x86_64/amd64** 和 **ARM64/aarch64** 架构。

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
| `--token` | 是 | 你的 TraffMonetizer 设备 Token |
| `--device` | 是 | 设备名称（可在 Dashboard 识别） |
| `-h` | 否 | 显示帮助信息 |

### 示例

```bash
sudo bash install.sh --token wzMpg94RU55m9GUbL/DtZVGHWeMnNleeGdWiOcDC4T8= --device my-vps
```

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

- OS: Linux (Debian/Ubuntu/CentOS/Fedora/Alpine 等)
- 架构: x86_64/amd64 或 ARM64/aarch64
- 权限: root (或 sudo)
- 网络: 需要访问互联网下载二进制文件

## 故障排查

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

### 服务启动失败

```bash
journalctl -u traffmonetizer -n 50 --no-pager
```

检查 Token 是否正确，网络连接是否正常。

## 技术说明

本脚本通过 systemd 管理服务而非 Docker，优势：

- 兼容所有 Linux 发行版
- 无需 Docker 环境
- 避免 seccomp/AppArmor 限制
- 资源占用极低（约 1MB 内存）
- 系统崩溃后自动重启

## License

MIT
