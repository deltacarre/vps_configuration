#!/bin/bash
# 设置脚本执行权限

echo "设置脚本执行权限..."

# 主脚本
chmod +x install.sh
chmod +x scripts/bootstrap.sh

# 核心模块
chmod +x scripts/core/*.sh

# 库文件
chmod +x scripts/lib/*.sh

echo "完成！所有脚本已设置执行权限"
