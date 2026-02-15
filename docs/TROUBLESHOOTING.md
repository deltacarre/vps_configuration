# 故障排查

本文档提供常见问题的诊断和解决方案。

## 🔍 诊断工具

### 快速诊断脚本
```bash
#!/bin/bash
# 快速诊断VPS配置状态

echo "=== SSH 配置 ==="
sudo sshd -t && echo "✓ SSH 配置正确" || echo "✗ SSH 配置错误"
echo "SSH 端口: $(sudo grep -r "^Port" /etc/ssh/sshd_config* | tail -1 | awk '{print $2}')"
echo ""

echo "=== 防火墙状态 ==="
sudo ufw status numbered
echo ""

echo "=== Fail2ban 状态 ==="
sudo systemctl is-active fail2ban && echo "✓ Fail2ban 运行中" || echo "✗ Fail2ban 未运行"
sudo fail2ban-client status sshd 2>/dev/null || echo "SSHD jail 未配置"
echo ""

echo "=== BBR 状态 ==="
echo "拥塞控制: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "队列调度: $(sysctl -n net.core.default_qdisc)"
echo ""

echo "=== Swap 状态 ==="
swapon --show
echo "Swappiness: $(sysctl -n vm.swappiness)"
```

保存为 `check-status.sh` 并运行：
```bash
chmod +x check-status.sh
sudo ./check-status.sh
```

---

## 🔐 SSH 问题

### 问题：无法通过 SSH 连接

#### 症状
```
ssh: connect to host x.x.x.x port 22: Connection refused
```

#### 诊断步骤

**1. 检查 SSH 服务状态**
```bash
# 通过 VNC/控制台登录后执行
sudo systemctl status ssh

# 如果服务未运行
sudo systemctl start ssh
sudo systemctl enable ssh
```

**2. 检查 SSH 端口**
```bash
# 查看配置的端口
sudo grep -r "^Port" /etc/ssh/

# 查看监听的端口
sudo ss -tlnp | grep sshd

# 或
sudo netstat -tlnp | grep sshd
```

**3. 测试 SSH 配置**
```bash
sudo sshd -t
# 如果有错误，会显示具体问题
```

**4. 检查防火墙**
```bash
sudo ufw status
# 确认 SSH 端口已放行
```

#### 解决方案

**方案 A：恢复 SSH 配置**
```bash
# 备份当前配置
sudo cp -r /etc/ssh/sshd_config.d /root/backup_ssh

# 临时允许密码登录（用于恢复访问）
sudo bash -c 'cat > /etc/ssh/sshd_config.d/99-temp-recovery.conf <<EOF
PasswordAuthentication yes
PermitRootLogin yes
EOF'

# 重启 SSH
sudo systemctl restart ssh
```

**方案 B：放行正确的端口**
```bash
# 如果改了端口但忘记放行
sudo ufw allow 2222/tcp
sudo ufw reload
```

**方案 C：检查日志找出问题**
```bash
# 查看 SSH 日志
sudo journalctl -u ssh -n 50 --no-pager

# 查看认证日志
sudo tail -50 /var/log/auth.log
```

---

### 问题：密钥认证失败

#### 症状
```
Permission denied (publickey)
```

#### 诊断步骤

**1. 检查客户端**
```bash
# 使用详细模式连接
ssh -vvv -p <port> user@host

# 检查本地密钥
ls -la ~/.ssh/
ssh-add -l
```

**2. 检查服务器端**
```bash
# 检查 authorized_keys
sudo cat /home/<user>/.ssh/authorized_keys

# 检查权限
sudo ls -la /home/<user>/.ssh/
# .ssh 应为 700
# authorized_keys 应为 600
```

#### 解决方案

**方案 A：修复权限**
```bash
sudo chmod 700 /home/<user>/.ssh
sudo chmod 600 /home/<user>/.ssh/authorized_keys
sudo chown -R <user>:<user> /home/<user>/.ssh
```

**方案 B：重新添加公钥**
```bash
# 在服务器上
sudo su - <user>
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "your-public-key" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**方案 C：检查 SELinux（如果使用）**
```bash
# 恢复 SELinux 上下文
sudo restorecon -Rv ~/.ssh
```

---

### 问题：SSH 连接很慢

#### 症状
连接时等待很久才显示密码/密钥提示

#### 诊断
```bash
# 查看 SSH 连接详细过程
ssh -vvv -p <port> user@host 2>&1 | grep -i "delay\|slow\|timeout"
```

#### 解决方案

**方案 A：禁用 DNS 反向解析**
```bash
# 编辑 SSH 配置
sudo vim /etc/ssh/sshd_config

# 添加或修改
UseDNS no

# 重启 SSH
sudo systemctl restart ssh
```

**方案 B：禁用 GSSAPI 认证**
```bash
# 在客户端 ~/.ssh/config 添加
Host *
    GSSAPIAuthentication no
```

---

## 🛡️ 防火墙问题

### 问题：防火墙阻止了正常服务

#### 症状
服务在本地运行但外部无法访问

#### 诊断
```bash
# 检查防火墙规则
sudo ufw status numbered

# 检查服务是否在监听
sudo ss -tlnp | grep <port>

# 测试端口（从本地）
curl -v localhost:<port>

# 测试端口（从外部，在本地机器运行）
telnet <server-ip> <port>
```

#### 解决方案

**方案 A：开放端口**
```bash
sudo ufw allow <port>/tcp
sudo ufw reload

# 验证
sudo ufw status | grep <port>
```

**方案 B：临时禁用防火墙测试**
```bash
# 仅用于诊断！
sudo ufw disable

# 测试服务是否可访问
# 如果可以，说明是防火墙问题

# 记得重新启用
sudo ufw enable
```

---

### 问题：防火墙规则错误

#### 症状
添加了规则但不生效

#### 诊断
```bash
# 查看 UFW 状态
sudo ufw status verbose

# 查看底层 iptables 规则
sudo iptables -L -n -v
```

#### 解决方案

**重置防火墙（小心！）**
```bash
# 警告：这会删除所有规则
sudo ufw --force reset

# 重新配置
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow <ssh-port>/tcp
sudo ufw enable
```

---

## 🚫 Fail2ban 问题

### 问题：Fail2ban 服务无法启动

#### 诊断
```bash
# 查看服务状态
sudo systemctl status fail2ban

# 查看错误日志
sudo journalctl -u fail2ban -n 50 --no-pager

# 测试配置
sudo fail2ban-client -x status
```

#### 解决方案

**方案 A：检查配置语法**
```bash
# 测试配置
sudo fail2ban-client -t

# 如果有错误，检查配置文件
sudo vim /etc/fail2ban/jail.d/sshd.local
```

**方案 B：重建配置**
```bash
# 备份错误的配置
sudo cp /etc/fail2ban/jail.d/sshd.local /root/backup/

# 重新创建
sudo bash scripts/core/06-fail2ban-setup.sh <ssh-port>
```

---

### 问题：IP 被错误封禁

#### 诊断
```bash
# 查看被封禁的 IP
sudo fail2ban-client status sshd

# 查看封禁日志
sudo grep "Ban" /var/log/fail2ban.log
```

#### 解决方案

**解封 IP**
```bash
sudo fail2ban-client set sshd unbanip <ip-address>

# 验证
sudo fail2ban-client status sshd
```

**配置白名单**
```bash
# 创建本地配置
sudo vim /etc/fail2ban/jail.local

# 添加
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 <your-trusted-ip>

# 重启服务
sudo systemctl restart fail2ban
```

---

## 💾 系统问题

### 问题：磁盘空间不足

#### 诊断
```bash
# 查看磁盘使用
df -h

# 查找大文件
sudo du -sh /* | sort -hr | head -10
sudo du -sh /var/* | sort -hr | head -10
```

#### 解决方案

**清理 APT 缓存**
```bash
sudo apt-get clean
sudo apt-get autoremove
```

**清理日志**
```bash
# 清理 journal 日志
sudo journalctl --vacuum-time=7d

# 清理旧日志
sudo find /var/log -type f -name "*.gz" -delete
sudo find /var/log -type f -name "*.old" -delete
```

**删除 swapfile（如果不需要）**
```bash
sudo swapoff /swapfile
sudo rm /swapfile
sudo sed -i '/swapfile/d' /etc/fstab
```

---

### 问题：内存不足

#### 诊断
```bash
# 查看内存使用
free -h

# 查看进程
ps aux --sort=-%mem | head -10

# 查看 OOM 日志
sudo dmesg | grep -i "out of memory"
```

#### 解决方案

**创建或增加 Swap**
```bash
# 检查当前 swap
swapon --show

# 创建 swapfile
sudo bash scripts/core/09-swap-optimization.sh create 2G
```

**重启占用内存多的服务**
```bash
# 示例：重启 Apache
sudo systemctl restart apache2
```

---

## 🌐 网络问题

### 问题：BBR 未生效

#### 诊断
```bash
# 检查内核版本
uname -r

# 检查当前拥塞控制算法
sysctl net.ipv4.tcp_congestion_control

# 检查模块
lsmod | grep tcp_bbr
```

#### 解决方案

**重新启用 BBR**
```bash
# 加载模块
sudo modprobe tcp_bbr

# 应用配置
sudo sysctl -p /etc/sysctl.d/99-vps-bbr.conf

# 验证
sysctl net.ipv4.tcp_congestion_control
```

**内核过旧需要升级**
```bash
# Debian/Ubuntu
sudo apt update
sudo apt install linux-image-amd64
sudo reboot
```

---

## 📊 性能问题

### 问题：系统响应慢

#### 诊断
```bash
# CPU 使用率
top
htop

# IO 等待
iostat -x 1 10

# 网络连接
ss -s
netstat -an | wc -l
```

#### 解决方案

**优化 Swap**
```bash
# 降低 swappiness
sudo sysctl vm.swappiness=10
```

**清理连接**
```bash
# 查找大量 CLOSE_WAIT 连接
ss -ant | awk '{print $1}' | sort | uniq -c

# 调整 TCP 参数
sudo sysctl net.ipv4.tcp_tw_reuse=1
```

---

## 🔄 恢复和重置

### 完全重置 SSH 配置

```bash
#!/bin/bash
# 重置 SSH 到初始状态

# 1. 备份当前配置
sudo cp -r /etc/ssh /root/backup_ssh_$(date +%Y%m%d_%H%M%S)

# 2. 删除自定义配置
sudo rm /etc/ssh/sshd_config.d/98-vps-*.conf
sudo rm /etc/ssh/sshd_config.d/99-vps-*.conf

# 3. 恢复默认端口和基本配置
sudo bash -c 'cat > /etc/ssh/sshd_config.d/00-reset.conf <<EOF
Port 22
PasswordAuthentication yes
PermitRootLogin yes
PubkeyAuthentication yes
EOF'

# 4. 重启 SSH
sudo systemctl restart ssh

echo "SSH 已重置，请测试连接"
```

### 完全重置防火墙

```bash
# 重置 UFW
sudo ufw --force reset
sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

### 系统恢复检查清单

- [ ] 能否通过 VNC/控制台登录
- [ ] SSH 服务是否运行
- [ ] SSH 端口是否正确
- [ ] 防火墙是否放行 SSH
- [ ] SSH 密钥是否正确
- [ ] Fail2ban 是否封禁了你的 IP
- [ ] 系统日志中是否有错误信息

---

## 🆘 紧急联系

如果以上方法都无法解决问题：

1. **使用 VPS 控制台**: 几乎所有 VPS 提供商都提供 VNC 或 Web 控制台
2. **重装系统**: 最后的手段，确保备份数据
3. **联系托管商**: 可能是网络或硬件问题
4. **提交 Issue**: https://github.com/deltacarre/vps_configuration/issues

---

## 📚 相关资源

- [安装指南](INSTALLATION.md)
- [配置说明](CONFIGURATION.md)
- [模块文档](MODULES.md)
- [常见问题](FAQ.md)
