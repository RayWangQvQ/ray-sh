# Prometheus

## Node Exporter Manager

Installation:

```
bash <(curl -sSL https://raw.githubusercontent.com/RayWangQvQ/ray-sh/main/prometheus/node_exporter_installer.sh)
```

If you are in a PAAS server like Serv00 and can not run as root, the following non-root version can be taken.
It can run node exporter successfully without some metrics:

```
bash <(curl -sSL https://raw.githubusercontent.com/RayWangQvQ/ray-sh/main/prometheus/node_exporter_installer_non_root.sh)
```

Features:

```
════════════════════════════════════════════════════════════════════
        » Node Exporter Manager «
        » Manager Version: 2025-04-25 «
        » Node Exporter Version: v1.9.1  «
════════════════════════════════════════════════════════════════════

请选择一个操作:
1) 全新安装 Node Exporter
2) 卸载 Node Exporter
3) 查看 Node Exporter 状态
4) 重启 Node Exporter 服务
5) 更新 Node Exporter 配置
6) 备份当前配置
7) 恢复配置备份
0) 退出
请输入选项 [0-7]:

```

## Blackbox Exporter Manager

todo