# pfQuest-epoch-zhCN · 纪元服任务数据库简体中文 Fork

> **非官方汉化派生项目**。本仓库是 [Bennylavaa/pfQuest-epoch](https://github.com/Bennylavaa/pfQuest-epoch) 的 GitHub Fork，不代表原作者、魔兽世界官方或 Project Epoch 官方。项目严格保留上游 LICENSE 与署名。此仓库的汉化工作使用了我们维护的 [EpochCN](https://github.com/z980944038-dev/EpochCN) 数据。

**开发基线**：pfQuest-epoch 3.3.0 + [Shagu pfQuest-wotlk 7.0.1](https://github.com/shagu/pfQuest/releases/tag/7.0.1)；WoW 3.3.5a。中文版本标记：`zhCN-beta.1`。**当前属于未经真实游戏客户端验收的测试版，不保证对复服后的所有任务完全准确。**

## 已实现

- 纪元数据库中 **2390 个任务 ID** 均关联到中文任务标题、目标与描述数据；个别原中文资料缺失的字段继续显示英文，避免凭空翻译。
- 物品、NPC、游戏物体和区域按 ID 结合 [EpochCN](https://github.com/z980944038-dev/EpochCN) 及 Shagu 官方 pfQuest 简体中文数据库生成译名，未匹配项回退英文。
- 使用原版 pfQuest 的任务日志翻译入口，同时默认选择简体中文（只在首次运行时设置，不会反复覆盖手动选择）。
- 英文任务 ID、英文客户端匹配表和世界地图坐标数据库保持原样；中文查询仅在原英文查询失败时回退。
- 任务详情扩展 Tooltip 展示中文标题与有译文的任务目标、描述，**不修改英文任务名索引**。
- 在英文客户端使用的 pfQuest 基础版界面上补充 Shagu 已有的简体中文 UI 文本（源自 MIT 许可的语言表）。

**重要限制**：地图、任务目标和提示的实际行为与 UI 是否完整中文，还需在真实的 Project Epoch 客户端验证。部分细分区域缺少经过验证的中文名称；翻译质量与上游任务变动须持续校对。详见 `localization/TRANSLATION_REPORT.json`。

## 安装（测试）

1. 下载并解压基础插件 [pfQuest-enUS-wotlk 7.0.1](https://github.com/shagu/pfQuest/releases/download/7.0.1/pfQuest-enUS-wotlk.zip)，使游戏目录中存在 `Interface/AddOns/pfQuest-wotlk/pfQuest-wotlk.toc`。
2. 从本仓库 [Releases](https://github.com/z980944038-dev/pfQuest-epoch-zhCN/releases) 下载带 `zhCN` 字样的测试版 ZIP，解压得到 `pfQuest-epoch` 目录，并放入同一 `Interface/AddOns/`。
3. 进入 3.3.5a 客户端的插件管理，启用 `pfQuest-wotlk`、`pfQuest-epoch`。输入 `/pfqzh` 查看中文状态；`/pfqzh on`、`/pfqzh off` 可切换，切换后执行 `/reload`。
4. 打开任务日志，使用 pfQuest 的语言选择入口检查“简体中文”；确认任务标题、目标与地点是否正确。

**必须保留原文件夹名称 `pfQuest-epoch`**：插件 TOC 内的 `GetAddOnMetadata("pfQuest-epoch", ...)` 依赖该名称。不要直接将 GitHub Fork 的仓库名作为游戏插件文件夹名。

与 [EpochCN](https://github.com/z980944038-dev/EpochCN) 同时安装时，两个插件可能重复绘制地图标记或处理任务文本，请在 EpochCN 中关闭重复地图标记，先分别验证再决定是否并用。完整客户端静态文字仍由 EpochCN 的 MPQ 层负责，不由本插件修改。

## 翻译策略和回归条件

- `db/enUS`、`db/*-epoch.lua` 原始任务 ID、英文数据和坐标**不变**。
- `db/zhCN` 独立存放译文；`localization/zhCN.lua` 负责加载、选择和显示，不覆盖英文名字索引。
- 数据缺少可信中文时回退原文；不会用不受控机器翻译猜测专名。
- 校验：`python3 tools/verify_translation.py`，以及在 `tools/` 中运行 `npm install --prefix tools && node tools/verify_lua.js && node tools/verify_runtime.js`（需要 Node.js；Lua 5.1 语法静态测试）。构建脚本 `tools/build_zhcn.py --help` 可查看依赖参数。
- 更新依赖的具体提交与来源参见 `localization/SOURCES.json`。构建后的质量报告记录待人工校核的任务。

## 许可和原作者

- **pfQuest-epoch**：原作者 Bennylavaa/Shagu 等，**[自定义 LICENSE](LICENSE)**。只允许个人使用和修改、通过 GitHub Fork 参与开发与贡献；**禁止**在未经授权的启动器、整合包、商业发行渠道或 GitHub Fork 之外的平台分发。请保留原版权信息和上游链接。
- **pfQuest（Shagu）**：简体中文 UI 与部分数据库译文来自其 MIT 许可项目。参见 [`localization/LICENSE-pfQuest-MIT.txt`](localization/LICENSE-pfQuest-MIT.txt)。pfQuest-wotlk 基础插件需单独从原仓库下载，本 Fork 不打包原基础插件。
- **EpochCN**：本团队维护的已有中文译文，原仓库链接如上，不包括游戏客户端、MPQ 或第三方素材。
- 原仓库文档另存为 [`README.upstream.md`](README.upstream.md)；修改记录与汉化来源独立保存。

游戏内功能验证尚未完成时，本项目只标记为 **Beta**，不会宣称正式稳定发布。
