# pfQuest-epoch-zhCN · 纪元任务插件简体中文维护版

这是 **[Bennylavaa/pfQuest-epoch](https://github.com/Bennylavaa/pfQuest-epoch)** 的非官方 GitHub Fork，由 [EpochCN](https://github.com/z980944038-dev/EpochCN) 维护者进行中文化与兼容维护。保留原作者署名、LICENSE、英文匹配数据、任务 ID 和坐标。

**当前版本：3.3.0 / zhCN-beta.3**。固定基础依赖：pfQuest-wotlk 7.0.1；目标客户端：WoW 3.3.5a / Project Epoch。

## 安装与升级

分别下载原作者的 [pfQuest-enUS-wotlk 7.0.1](https://github.com/shagu/pfQuest/releases/download/7.0.1/pfQuest-enUS-wotlk.zip) 和本仓库 [Beta 3 安装包](https://github.com/z980944038-dev/pfQuest-epoch-zhCN/releases/tag/v3.3.0-zhCN-beta.3)。解压后目录为：

```text
Interface/AddOns/pfQuest-wotlk/pfQuest-wotlk.toc
Interface/AddOns/pfQuest-epoch/pfQuest-epoch.toc
```

升级前退出游戏，将旧 `pfQuest-epoch` 文件夹移出 AddOns 目录作备份，再放入新版同名文件夹。保留角色 WTF 设置，不同时启用新旧两份扩展。不要把仓库名 `pfQuest-epoch-zhCN-main` 当作插件安装目录名。

`/pfqzh` 查看状态；`/pfqzh on` 开启、`/pfqzh off` 关闭，切换后 `/reload`。关闭时恢复原来的任务语言选择。本包不分发、不替换客户端字体或 MPQ，客户端必须已有中文字库。

## Beta 3 的实质更新

| 范围 | 当前中文数据覆盖 |
|---|---:|
| 纪元任务 | 2390 个 ID；7170 个标题／目标／描述字段受检查 |
| 物品名称 | 5948 / 5948 |
| NPC／单位名称 | 2265 / 2265 |
| 游戏物体 | 803 / 813；10 个空名、内部模型名、虚构语标识明确保留 |
| 区域名称 | 2363 / 2363；测试区、未使用区也标注中文性质 |

这些统计只针对 pfQuest-epoch 3.3.0 扩展数据库，不冒充全部游戏客户端或所有基础任务的汉化统计。保留英文原始数据库用于服务端匹配；静态客户端、字体与 MPQ 仍属于 EpochCN 的另一层工作。

本轮相对 Beta 2 更新 **555 个任务字段、700 个物品译名、33 个单位译名、6 个物体译名与708个区域译名**；区域中698条为新增译名。不是简单将已有中文当作正确：检查发现并纠正了 **690 条旧库 ID 错配**，普通鱼类、运输箱、物资袋和装备被误译为“副本钥石”的情况已消除，并新增防回归规则。

区域采用与原英文名称精确匹配的 LibBabble 词条和逐项校订。优先使用支持3.3.5的r23词库；后续词库仅补核对过的同名中文，不引入新版区域ID、地图或坐标。专名、型号、指令和原文校订均保留来源及摘要。

导航箭头、跑尸提示、掉落面板、本地版本提示补充中文。显示层对已知完整句式进行翻译，保留“使用物品／目标”和“掉落物品／来源”的参数顺序，避免只有词语变成中文、句意却错位。

## 不机械消灭所有英文字母

`localization/PRESERVED_TEXT.json` 逐条记录保留内容：可执行 `/bow` 命令、机构编号 `SI:7`、人物首字母、型号 `A`／`K3`、装置缩写，以及剧情明确要求破译的恶魔语。

检查器对中文任务与实体名称逐字段扫描。未归类的英文会导致构建失败；“包含一个汉字”不再等于“已汉化”。原始 enUS 库、程序接口、通信协议、URL、插件名称和开发诊断文字不计入该残留指标，也不会为追求数字而被替换。

**残留检查通过不等于所有故事都逐句人工润色完毕。** 继承译文仍可能有风格或语义问题；纪元自定义专名中包含社区音译，不宣称全部属于官方译名。

## EpochCN 并存

本 Fork 不修改 EpochCN 主仓库、存档或地图开关。检测到 EpochCN 后，不默认接管它的任务详情语言；仅在 pfQuest 已知匹配路径使用其保存的原始服务端 API，保留 EpochCN 面向玩家的中文接口。显示层不改写地图节点身份、英文索引、物品链接ID、玩家姓名或组队协议。

## 自动化检查

```sh
python3 tools/run_checks.py --bootstrap
```

需要 Python 3.12+、C 编译器和 make。命令只在仓库内下载并构建 SHA256 固定的原生 Lua 5.1.5 和基础插件，不需要 API Key、游戏账号或全局安装。每次 push／PR 由 GitHub Actions 独立运行同样检查。

包括39个Lua文件语法、49份基础源文件固定、任务数量与控制符、英文数据完整性、残留分类、八种运行场景和七种主动故障注入。安装包独立构建两次，校验哈希与包内清单。结果和边界见 [QA_REPORT.md](QA_REPORT.md) 与 `qa/BETA3_RESULT.json`。

```sh
python3 tools/audit_english.py
python3 tools/build_zhcn.py --help
python3 tools/package_release.py
```

这是预发布 **Beta**。原生Lua测试中的UI和事件对象是测试替身，不等于真实游戏渲染、全部插件组合或战斗保护机制已经验收。

## 许可与来源

原项目 [自定义许可证](LICENSE) 允许个人使用、修改和 GitHub Fork；不得擅自加入启动器、整合包、商业渠道或在允许范围之外再分发。原说明保存在 [README.upstream.md](README.upstream.md)。

基础中文资料来自我们维护的 EpochCN 固定提交与 Shagu pfQuest 7.0.1。补充区域词条来自 MIT 许可的 LibBabble-SubZone-3.0（arith及贡献者）。[Shagu MIT](localization/LICENSE-pfQuest-MIT.txt) 和 [LibBabble MIT](localization/LICENSE-LibBabble-MIT.txt) 署名均保留；具体文件摘要、来源、校订及保留规则位于 `localization/`。不打包基础插件、凭据或字体。
