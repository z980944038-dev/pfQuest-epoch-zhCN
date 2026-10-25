# pfQuest-epoch-zhCN · 纪元任务插件简体中文维护版

本仓库是 **[Bennylavaa/pfQuest-epoch](https://github.com/Bennylavaa/pfQuest-epoch)** 的非官方 GitHub Fork，由 [EpochCN](https://github.com/z980944038-dev/EpochCN) 维护者进行中文化与兼容修复。原作者的许可证、署名和英文数据保留，不能将本项目误称为原作者或服务器官方版本。

**当前版本：3.3.0 / zhCN-beta.2**。固定基础依赖为 **pfQuest-wotlk 7.0.1**，目标为 WoW 3.3.5a / Project Epoch。

## 安装

下载原作者的 [pfQuest-enUS-wotlk 7.0.1](https://github.com/shagu/pfQuest/releases/download/7.0.1/pfQuest-enUS-wotlk.zip) 和本仓库 [Releases](https://github.com/z980944038-dev/pfQuest-epoch-zhCN/releases) 中带 `zhCN-beta.2` 标识的安装包。解压后应为：

```text
Interface/AddOns/pfQuest-wotlk/pfQuest-wotlk.toc
Interface/AddOns/pfQuest-epoch/pfQuest-epoch.toc
```

升级时先退出游戏，将原 `pfQuest-epoch` 文件夹移到游戏目录之外作备份，再放入新版同名文件夹；保留 `WTF` 中的角色设置。不要把新旧版本两个文件夹同时放进 AddOns，也不要使用仓库下载后带 `-main` 或 `-zhCN` 的目录名代替 `pfQuest-epoch`。

`/pfqzh` 查看状态，`/pfqzh on` 开启中文，`/pfqzh off` 关闭中文。开关在 `/reload` 后生效，关闭时恢复此前的任务语言选择。客户端需要已有中文字库；本包不携带、不分发、不替换字体或 MPQ。

## Beta 2 改了什么

| 内容 | 本版状态 |
|---|---|
| 纪元任务 | 2390 个 ID；7170 个标题、目标、描述字段通过数量、占位符、颜色标记等静态检查 |
| 物品名称 | 5948 / 5948 已有中文；统一 402 条同系列装备的术语 |
| NPC / 单位名称 | 2265 / 2265 已有中文，纪元专名中包含社区音译 |
| 游戏物体 | 803 / 813 中文；其余为 5 个空名、1 个内部模型名、4 段虚构语言，保留原样 |
| 区域名称 | 1665 / 2363 中文；余下 698 条保留英文并列入检查结果，不计入已完成 |
| 界面 | pfQuest 自有设置、追踪标签、数据库窗口与主动绘制的 Tooltip 接入中文显示层 |
| 英文匹配 | 英文名称表、任务 ID、坐标、服务端 API 原样保留；显示中文不再改写匹配键 |

本版逐条校订了一批有明确问题的任务字段，包括错误的物品数量、遗漏的声望门槛、灵魂状态提示、玩家称呼、性别模板和误译的否定句。校订记录在 [`localization/REVIEWED_OVERRIDES.json`](localization/REVIEWED_OVERRIDES.json)，每项绑定当前英文原文 SHA256，源任务变动时构建会报错，不会悄悄沿用过时校订。

这些数字表示数据覆盖与规定检查的结果，**不表示每一段继承译文都完成了人工文学润色，也不表示真实游戏客户端已经验收**。本版仍标记为 Beta。完整范围见 [`QA_REPORT.md`](QA_REPORT.md) 和 [`qa/BETA2_RESULT.json`](qa/BETA2_RESULT.json)。

## EpochCN 并存

本 Fork 不修改 EpochCN 仓库、存档或地图开关。检测到 EpochCN 后，默认不再替它接管任务详情语言；通过 EpochCN 保存的原始 API 给 pfQuest 的匹配、进度与组队数据提供服务端文本，同时保留 EpochCN 全局 API 的中文返回值。

兼容层只作用于 pfQuest 的已知函数，不重写全局 `GetLocale`、任务接口或通信函数。当前测试包含与 EpochCN 相同接口契约的中文 API 替身，并执行真实的 pfQuest 数据库和地图 Tooltip 代码；不把这个检查等同于加载所有第三方插件的完整游戏实测。

## 开发与发布检查

一次命令执行原生 Lua 5.1 编译检查、完整数据校验、八类运行场景、四类故障注入，以及两次独立打包的一致性检查：

```sh
python3 tools/run_checks.py --bootstrap
```

需要 Python 3.12+、C 编译器和 make。该命令只在本仓库 `.qa-deps/` 下载并构建 SHA256 固定的原版 Lua 5.1.5，以及读取原作者的基础插件；无需 API Key、游戏账号或全局安装。结果写入 `.qa-results/RESULT.json`。

已有本地依赖时：

```sh
python3 tools/run_checks.py --lua /path/to/lua5.1 --luac /path/to/luac5.1 --base-dir /path/to/pfQuest-wotlk
```

汉化数据可通过 `tools/build_zhcn.py --help` 查看重建参数。打包用 `python3 tools/package_release.py`，只打入插件运行文件、安装说明和必要许可证，不打入基础插件、开发依赖、凭据或客户端素材。

## 许可证与来源

原项目采用[自定义许可证](LICENSE)，允许个人使用、修改与 GitHub Fork；不得擅自加入启动器、整合包、商业发行渠道或在 GitHub Fork 之外重新分发。原说明保存在 [README.upstream.md](README.upstream.md)。

基础语言数据与 UI 译文来自 Shagu pfQuest 7.0.1（[MIT 许可证副本](localization/LICENSE-pfQuest-MIT.txt)）；已有中文任务数据来自我们维护的 EpochCN 固定提交。具体来源、摘要和校订说明见 [`localization/SOURCES.json`](localization/SOURCES.json)。
