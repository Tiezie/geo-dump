# geo-dump

两个独立的 Xray 数据库查看工具：`geosite-dump` 查看和搜索域名规则，`geoip-dump` 查看网段、查询 IP 所属分类。纯 Python 3，无第三方 Python 库依赖。

## 一键安装

在 Linux VPS 上，以 root 执行：

```sh
curl -fsSL https://raw.githubusercontent.com/Tiezie/geo-dump/main/install.sh | sh
```

普通用户使用 sudo：

```sh
curl -fsSL https://raw.githubusercontent.com/Tiezie/geo-dump/main/install.sh | sudo sh
```

前提是已有 `curl`。Debian/Ubuntu 可先运行 `sudo apt-get update && sudo apt-get install -y curl`。

安装程序将两个命令安装到 `/usr/local/bin`，自动安装缺失的 Python 3（支持 apt、dnf、yum、apk），校验下载文件的 SHA256，并验证脚本可启动。安装失败时尝试恢复安装前的两个命令。它不升级整个系统，不下载或修改 Xray 数据库、配置和服务。

首次安装需要联网。已有工具会被仓库版本替换，重复运行同一命令可更新工具。SHA256 用于验证脚本与本次下载的清单一致；内容来源仍是这个 GitHub 仓库。

## 马上使用

```sh
geosite-dump info
geosite-dump search openai
geosite-dump show google
geoip-dump info
geoip-dump lookup 8.8.8.8 -v
geoip-dump contains private 192.168.1.1
```

默认读取已有的：

- `/usr/local/share/xray/geosite.dat`
- `/usr/local/share/xray/geoip.dat`

仓库不包含数据库；查询前须有相应数据文件。已有 Xray 数据库在默认路径时，安装后即可直接使用。其他路径通过 `-f` 指定（放在子命令之前）：

```sh
geosite-dump -f /path/geosite.dat search openai
geoip-dump -f /path/geoip.dat lookup 8.8.8.8
```

完整参数和示例请看 [使用说明](docs/使用说明.md)，也可运行：

```sh
geosite-dump --help
geoip-dump --help
geosite-dump search --help
geoip-dump lookup --help
```

注意：geosite 的 `search` 搜索规则文本；geoip 的 `search` 搜索分类名称，查询 IP 请用 `lookup` / `contains`。查询结果依据数据库内容，不等于最终 Xray 路由结果。

## 手动安装与自定义目录

```sh
git clone https://github.com/Tiezie/geo-dump.git
cd geo-dump
sudo env GEO_DUMP_SOURCE_DIR="$PWD" sh install.sh
```

已有 Python 3 时，普通用户可安装到自己的目录：

```sh
GEO_DUMP_INSTALL_DIR="$HOME/.local/bin" GEO_DUMP_SOURCE_DIR="$PWD" sh install.sh
export PATH="$HOME/.local/bin:$PATH"
```

可用 `GEO_DUMP_REF` 选择一个已存在的分支或完整提交 SHA；首次下载的 install.sh 也应使用相同引用。

## 卸载

默认安装只增加两个工具文件；卸载它们：

```sh
sudo rm -f -- /usr/local/bin/geosite-dump /usr/local/bin/geoip-dump
```

自定义目录安装时，相应调整路径。数据库保持不变。Python 3 可能被其他软件使用，不要因卸载这两个工具就直接删除它。
