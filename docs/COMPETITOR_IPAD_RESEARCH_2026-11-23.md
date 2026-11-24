# 对标产品 iPad 界面调研 — 小提琴学习 App

日期：2026-11-23 · 方法：App Store 公开 iPad 截图（2048 × 2732）+ 产品页描述；仅用于设计分析，不复制其界面或资产。

## 样本

| 产品 | App Store | iPad 截图观察 |
|---|---|---|
| Trala: Learn Violin | <https://apps.apple.com/us/app/trala-learn-violin/id1143205265> | 横屏练习画布：左侧窄导航（汉堡），中央大块音高/乐谱画布，提示气泡浮在内容上 |
| tonestro | <https://apps.apple.com/us/app/learn-play-violin-tonestro/id1590492511> | 3 列封面卡片曲库 + 下方列表；练习页整屏乐谱，反馈点直接画在谱面上 |
| 来音小提琴 | <https://apps.apple.com/cn/app/id1628747999> | 6 宫格功能卡（趣味练习/调音器/谱库/模拟器/音调仪/节拍器）；曲库是 2 列乐谱卡；模拟器为沉浸式浮层 |
| 一起练琴 | <https://apps.apple.com/cn/app/id1263079672> | 谱库：搜索 + 5 个彩色入口 + 4 列教材封面 + 2 列单曲；示范页：上方大视频、下方乐谱、底部工具条 |

> 截图证据来自 App Store `ipadScreenshotUrls`（本次抓取为 2048×2732）；仅作本地对比，不随仓库分发。

## 共同模式

1. **内容优先，界面让位**：练习/看谱时，谱面或演奏画布接近整屏；控件悬浮在上下边缘，而不是用卡片把内容包起来。
2. **多列内容库**：教材/曲谱用 2–5 列封面网格，单曲用 2 列列表；没有一家用「一行一个 PDF」的长列表。
3. **横屏是练习主场景**：Trala、tonestro、一起练琴的练习截图都是横屏；iPad 版不是把 iPhone 竖屏放大。
4. **导航轻量**：左侧窄栏/汉堡/顶部少量入口；不堆 5 个以上同级 Tab。
5. **沉浸式练习**：来音的模拟器、tonestro 的谱面反馈都是全屏/浮层，退出才回到库。
6. **视觉锚点**：封面图、彩色功能卡、真实谱面，比纯文字卡片更有辨识度。

## 对 dorewio 的取舍

采用：
- PDF 谱架改为**封面网格**（已实现，见 `docs/screenshots/app-1.1/ipad/04_pdf_shelf.png`）。
- 曲库/训练入口在 iPad 上用**多列卡片/网格**，而不是长列表（下一步）。
- 练习页保持**内容区优先**：第一课指板、调音表盘、PDF 阅读器占主要面积，控制放在侧栏/底部。
- 横屏时优先保证谱面/指板完整可见，控件收窄（下一步，需真机/Simulator 旋转验证）。

不采用：
- 订阅墙、账号、强制联网、平台曲库——与 dorewio 离线、自带谱、买断的定位相反。
- 大量营销插画/视频封面——我们是工具型，封面只用于用户导入的 PDF。
- 5 列以上的密集封面——dorewio 的 PDF 通常是个位数，2–4 列足够。

## 已落地 vs 待做

| 项 | 状态 |
|---|---|
| PDF 谱架封面网格 + 首页缩略图 | 已实现 |
| iPad 常规宽度两栏 dashboard | 已实现 |
| 可转换侧边栏入口 | 已实现（系统 toggle） |
| 学习/训练改为 2 列功能卡 | 待做 |
| 横屏沉浸式练习（谱面/指板全屏） | 待做，需旋转验证 |
| 键盘快捷键 / pointer hover | 待做 |

## 参考

- App Store 产品页（见上表）
- Apple HIG Layout: <https://developer.apple.com/design/human-interface-guidelines/layout>
- Apple HIG Designing for iPadOS: <https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados>
