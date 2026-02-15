# 常见问题 (FAQ)

## 🔐 SSH 相关

### Q: 为什么必须提供 SSH 公钥？
**A**: 为了安全，脚本会禁用密码登录，只允许密钥认证。如果不配置公钥就禁用密码登录，会导致无法登录服务器。

### Q: 如何生成 SSH 密钥？
**A**: 
```bash
# 推荐使用 ED25519 算法
ssh-keygen -t ed25519 -C "your_email@example.com"

# 也可以使用 RSA（需要 4096 位）
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 查看公钥
cat ~/.ssh/id_ed25519.pub
```

### Q: 脚本执行后无法 SSH 登录怎么办？
**A**: 
1. 检查 VPS 提供商是否提供 VNC/Web 控制台
2. 通过控制台登录（使用 root 账号）
3. 检查配置文件：
   ```bash
   cat /etc/ssh/sshd_config.d/99-vps-hardening.conf
   ```
4. 暂时允许密码登录：
   ```bash
   sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/99-vps-hardening.conf
   systemctl restart ssh
   ```

### Q: 忘记设置的 SSH 端口怎么办？
**A**: 
```bash
# 方法1：查看配置文件
grep -r "Port" /etc/ssh/sshd_config.d/

# 方法2：查看防火墙规则
sudo ufw status

# 方法3：查看 netstat
sudo netstat -tlnp | grep sshd
```

### Q: 可以同时使用密码和密钥登录吗？
**A**: 可以，但不推荐。如需启用：
```bash
# 编辑配置
vim /etc/ssh/sshd_config.d/99-vps-hardening.conf

# 修改为
PasswordAuthentication yes

# 重启 SSH
systemctl restart ssh
```

---

## 🛡️ 防火墙相关

### Q: 防火墙会不会锁死我的服务器？
**A**: 不会。脚本会自动放行当前 SSH 端口，确保不会断开连接。

### Q: 如何临时关闭防火墙？
**A**: 
```bash
# 不推荐，仅用于故障排查
sudo ufw disable

# 完成后记得重新启用
sudo ufw enable
```

### Q: 如何开放新端口？
**A**: 
```bash
# 开放单个端口
sudo ufw allow 80/tcp

# 开放端口范围
sudo ufw allow 8000:9000/tcp

# 允许特定 IP
sudo ufw allow from 192.168.1.100

# 查看规则
sudo ufw status numbered
```

### Q: 如何删除防火墙规则？
**A**: 
```bash
# 查看规则编号
sudo ufw status numbered

# 删除指定编号的规则
sudo ufw delete 3

# 或直接删除
sudo ufw delete allow 80/tcp
```

---

## 🚫 Fail2ban 相关

### Q: Fail2ban 会不会封禁自己？
**A**: 不太可能，但如果不小心输错密码多次可能会。建议：
- 使用密钥登录（不会被封禁）
- 配置白名单 IP

### Q: 如何解封被 Fail2ban 封禁的 IP？
**A**: 
```bash
# 查看被封禁的 IP
sudo fail2ban-client status sshd

# 解封特定 IP
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

### Q: 如何配置 IP 白名单？
**A**: 
```bash
# 编辑配置
sudo vim /etc/fail2ban/jail.local

# 添加
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 <your_ip>

# 重启服务
sudo systemctl restart fail2ban
```

### Q: Fail2ban 日志在哪里？
**A**: 
```bash
# 查看日志
sudo tail -f /var/log/fail2ban.log

# 或使用 journalctl
sudo journalctl -u fail2ban -f
```

---

## 💾 Swap 相关

### Q: 我的服务器内存充足，需要 Swap 吗？
**A**: 
- 内存 > 4GB: 不是必需，但建议保留小量 Swap（1-2GB）作为应急
- 内存 < 4GB: 强烈建议创建 Swap

### Q: Swap 大小如何选择？
**A**: 
| 物理内存 | 推荐 Swap 大小 |
|---------|--------------|
| < 2GB   | 2x 内存      |
| 2-4GB   | 1x 内存      |
| 4-8GB   | 0.5x 内存    |
| > 8GB   | 2-4GB        |

### Q: 如何修改 Swappiness？
**A**: 
```bash
# 临时修改
sudo sysctl vm.swappiness=10

# 永久修改
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-vps-swap.conf
sudo sysctl -p /etc/sysctl.d/99-vps-swap.conf
```

### Q: 如何删除 Swapfile？
**A**: 
```bash
# 禁用 swap
sudo swapoff /swapfile

# 从 fstab 中删除
sudo sed -i '/swapfile/d' /etc/fstab

# 删除文件
sudo rm /swapfile
```

---

## 🌐 BBR 相关

### Q: 我的内核版本过低，如何升级？
**A**: 
```bash
# Debian 12 默认内核已支持 BBR
# 检查内核版本
uname -r

# 如果需要升级（Debian）
sudo apt update
sudo apt install linux-image-amd64
sudo reboot
```

### Q: 如何验证 BBR 是否生效？
**A**: 
```bash
# 方法1：检查拥塞控制算法
sysctl net.ipv4.tcp_congestion_control
# 应输出: net.ipv4.tcp_congestion_control = bbr

# 方法2：检查队列调度
sysctl net.core.default_qdisc
# 应输出: net.core.default_qdisc = fq

# 方法3：检查模块
lsmod | grep tcp_bbr
```

### Q: BBR 对网速提升明显吗？
**A**: 
- 国际线路/高延迟网络：提升明显（20-100%）
- 国内优质线路：提升有限（5-20%）
- 局域网：基本无提升

---

## ⚙️ 配置相关

### Q: 可以多次运行脚本吗？
**A**: 可以。脚本设计为幂等的，多次运行不会造成问题。已存在的配置会被保留或更新。

### Q: 如何只执行部分模块？
**A**: 
```bash
# 方法1：修改配置文件
ENABLE_BBR="no"
ENABLE_SWAP="no"

# 方法2：直接运行单个模块
sudo bash scripts/core/04-ssh-hardening.sh
```

### Q: 配置文件中的 yes/no 可以用 true/false 吗？
**A**: 不可以。必须使用 `yes` 或 `no`（小写）。

### Q: 如何备份配置？
**A**: 
```bash
# 备份整个配置目录
cp -r /etc/ssh/sshd_config.d /root/backup_ssh_$(date +%Y%m%d)
cp /etc/sysctl.d/99-vps-*.conf /root/backup_sysctl/

# 或使用脚本自动备份功能
# 脚本会自动创建 .backup 文件
```

---

## 🔧 系统相关

### Q: 脚本支持哪些系统？
**A**: 
- **完全支持**: Debian 12 (Bookworm)
- **基本支持**: Debian 11, Ubuntu 22.04/24.04
- **未测试**: CentOS, RHEL, Fedora

### Q: 脚本会删除现有配置吗？
**A**: 不会。脚本会：
- 备份现有配置（添加 `.backup` 后缀）
- 使用 drop-in 配置文件（不修改主配置）
- 保留现有规则

### Q: 如何完全卸载？
**A**: 
```bash
# 1. 删除配置文件
sudo rm /etc/ssh/sshd_config.d/98-vps-*.conf
sudo rm /etc/ssh/sshd_config.d/99-vps-*.conf
sudo rm /etc/sysctl.d/99-vps-*.conf
sudo rm /etc/apt/apt.conf.d/99-vps-*.conf
sudo rm /etc/fail2ban/jail.d/sshd.local

# 2. 重启服务
sudo systemctl restart ssh
sudo systemctl restart fail2ban
sudo sysctl --system

# 3. 删除 swapfile（如果创建了）
sudo swapoff /swapfile
sudo rm /swapfile
sudo sed -i '/swapfile/d' /etc/fstab
```

---

## 📊 监控和日志

### Q: 如何查看系统日志？
**A**: 
```bash
# SSH 日志
sudo journalctl -u ssh -f

# Fail2ban 日志
sudo journalctl -u fail2ban -f

# 系统日志
sudo journalctl -f

# 认证日志
sudo tail -f /var/log/auth.log
```

### Q: 如何监控服务器资源？
**A**: 
```bash
# 安装监控工具（脚本已安装 htop）
htop

# 检查内存
free -h

# 检查磁盘
df -h

# 检查网络连接
ss -tulpn
```

---

## 🆘 紧急情况

### Q: 服务器被锁死无法登录怎么办？
**A**: 
1. 使用 VPS 提供商的 VNC/Web 控制台
2. 使用 root 账号登录
3. 恢复备份配置或临时允许密码登录
4. 重启 SSH 服务

### Q: 防火墙配置错误导致无法访问怎么办？
**A**: 
```bash
# 通过 VNC 控制台登录后
sudo ufw disable
sudo ufw allow <your_ssh_port>/tcp
sudo ufw enable
```

### Q: 如何重置所有配置？
**A**: 
```bash
# 警告：这会恢复到初始状态
sudo rm /etc/ssh/sshd_config.d/9*-vps-*.conf
sudo rm /etc/sysctl.d/99-vps-*.conf
sudo systemctl restart ssh
sudo sysctl --system
```

---

## 📚 更多帮助

如果以上内容没有解决你的问题：

1. 查看 [故障排查文档](TROUBLESHOOTING.md)
2. 查看 [模块文档](MODULES.md) 了解详细功能
3. 提交 Issue: https://github.com/deltacarre/vps_configuration/issues
4. 查看项目 Wiki

---

## 💡 提示

- 在生产环境部署前，建议先在测试环境验证
- 保存好你的 SSH 密钥和端口号
- 定期备份重要配置
- 保持系统和软件包更新
