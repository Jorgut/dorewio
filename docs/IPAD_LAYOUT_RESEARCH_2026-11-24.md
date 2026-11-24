# 其他项目 iPad 布局研究 — 2026-11-24

目的：在继续改 dorewio 的 iPad 布局前，先看同类/邻近产品怎么做 iPad，再决定 iPhone 与 iPad 是否要「完全统一」。

样本：App Store 公开 iPad 截图（2048×2732 或横屏 2732×2048）+ 产品定位。截图只作本地分析，不提交进仓库。

## 样本与布局类型

| 产品 | 类型 | iPad 布局观察 | 证据 |
|---|---|---|---|
| forScore | 谱架/标注 | 左侧元数据栏 + 右侧谱面详情；看谱时整屏谱面，标注工具浮在谱面上方 | <https://apps.apple.com/us/app/forScore/id363738376> |
| Newzik | 谱架/协作 | 整屏谱面 + 浮动标注/播放；以内容为主 | <https://apps.apple.com/us/app/newzik-sheet-music-reader/id966963109> |
| MuseScore | 谱库/播放 | 大图封面、曲库浏览；营销图为主 | <https://apps.apple.com/us/app/musescore-sheet-music-chords/id835731296> |
| flowkey | 钢琴学习 | 横屏：上方真人手型视频、下方谱面，底部进度条；整屏练习 | <https://apps.apple.com/us/app/flowkey-learn-to-play-piano/id1020357408> |
| Yousician | 乐器学习 | 横屏练习画布，音符/反馈直接叠在内容上 | <https://apps.apple.com/us/app/yousician-learn-play-guitar/id959883039> |
| Simply Piano | 钢琴学习 | 横屏谱面 + 琴键/反馈，内容占满屏幕 | <https://apps.apple.com/us/app/simply-piano-learn-piano-fast/id1019442026> |
| GarageBand | 音乐创作 | 横屏 4–5 列声音包网格，顶部工具栏，内容优先 | <https://apps.apple.com/us/app/garageband/id408709785> |
| Violy | 小提琴练习 | 竖屏 dashboard：数据卡 + 日历 + 进度，信息密度高 | <https://apps.apple.com/us/app/violy-violin-demo-practice/id1357516375> |
| Trala | 小提琴学习 | 横屏练习画布，左侧窄导航，提示浮在画面上 | <https://apps.apple.com/us/app/trala-learn-violin/id1143205265> |
| tonestro | 小提琴学习 | 3 列封面曲库 + 列表；练习页整屏谱面反馈 | <https://apps.apple.com/us/app/learn-play-violin-tonestro/id1590492511> |
| 来音小提琴 | 工具+陪练 | 6 宫格工具卡、2 列乐谱卡；模拟器为沉浸式浮层 | <https://apps.apple.com/cn/app/id1628747999> |
| 一起练琴 | 陪练 | 搜索 + 5 个彩色入口 + 4 列教材封面 + 2 列单曲 | <https://apps.apple.com/cn/app/id1263079672> |

## 四种可复用的 iPad 布局原型

1. **沉浸式画布**（forScore、Trala、tonestro、flowkey、Yousician）
   - 谱面/视频/练习画布接近整屏；工具栏、播放条、标注浮层在边缘。
   - 适合 dorewio 的第一课、指板、调音、PDF 阅读、乐谱跟奏。

2. **左栏 + 内容详情**（forScore 元数据、Trala 左窄栏）
   - 左栏放集合/属性/章节，右侧放大内容；不是把列表堆在中间。

3. **多列内容库**（tonestro、一起练琴、GarageBand、乐音）
   - 3–5 列封面/卡片；搜索和分类在顶部。
   - 适合 dorewio 的 PDF 谱架、学习模块、训练入口。

4. **竖屏 dashboard**（Violy、来音首页）
   - 数据卡、日历、进度，2 列为主；适合「今天 / 进度」。

## iPhone 和 iPad 要不要完全统一？

**不要完全统一。** 统一的是设计系统、功能、术语和心智模型；不统一的是布局组合。

| 层面 | 应该统一 | 应该分化 |
|---|---|---|
| 品牌/颜色/字体/图标 | ✅ 同一套 | — |
| 功能与信息架构 | ✅ 同样 5 个分区、同样术语 | — |
| 组件（卡片、按钮、进度环、练习控件） | ✅ 同一套 SwiftUI 组件 | — |
| 页面组合 | — | iPhone 单列；iPad 两栏/多栏 |
| 导航容器 | 同一套 `TabView` | iPhone 底部标签栏；iPad 顶部标签栏 + 可转换侧边栏 |
| 内容密度 | 同一内容 | iPad 多列封面、左右分栏；iPhone 单列 |
| 方向 | 都可用 | iPad 练习页优先横屏；iPhone 以竖屏为主 |
| 输入 | 同一功能 | iPad 加键盘快捷键、pointer hover；iPhone 以触控为主 |

判断标准：

- 如果 iPad 只是把 iPhone 单列拉宽，就是「完全统一」的坏结果（之前那版）。
- 如果 iPhone 和 iPad 各写一套页面、各维护一套状态，就是「完全分化」的坏结果。
- 正确做法是**一套组件 + 一套状态 + 按 size class 组合**：iPhone 单列、iPad 两栏/网格、练习页沉浸式。

## 对 dorewio 的具体结论

保留（已经是统一的部分）：

- 同一套 5 个分区：今天 / 学习 / 训练 / 曲目 / 进度。
- 同一套 `PracticePalette`、卡片 surface、按钮、字体层级。
- 同一套内容与课程，不为 iPad 单独做功能。

iPad 继续分化（按上面的原型）：

1. **今天 / 进度**：两栏 dashboard（已做）；iPhone 保持单列。
2. **曲目**：左侧大块乐谱/PDF 工作区，右侧 PDF 封面网格 + 音频入口；iPhone 上下堆叠。
3. **学习 / 训练**：iPad 2–3 列功能卡网格；iPhone 单列列表。
4. **第一课 / 指板 / 调音 / PDF 阅读**：iPad 内容区优先，控制收进侧栏或底部浮条；iPhone 上下堆叠。
5. **横屏练习**：谱面/指板全屏，工具栏浮在顶部；需要旋转/分屏实测后再定。

不做：

- 不为 iPad 单独做一套导航/功能/术语。
- 不把 iPhone 的 5 个底部 Tab 原样放大成 iPad 的居中窄栏。
- 不照搬竞品的订阅墙、平台曲库、密集营销封面。

## 下一步顺序

1. 学习/训练改成 iPad 功能卡网格（不需要旋转，先做）。
2. 曲目改成「左工作区 + 右 PDF 网格」的稳定两栏（不需要旋转）。
3. 第一课/调音在 iPad 上把控制收进侧栏，内容区加大（不需要旋转）。
4. 横屏沉浸式练习（需要 Xcode Simulator 旋转或真机，当前环境无法截图验证）。
5. 键盘快捷键 + pointer hover。

## 参考

- Apple HIG Layout: <https://developer.apple.com/design/human-interface-guidelines/layout>
- Apple HIG Designing for iPadOS: <https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados>
- 已有竞品分析：`docs/COMPETITOR_IPAD_RESEARCH_2026-11-23.md`
- 设计 QA：`docs/DESIGN_QA_IPAD_2026-11-23.md`
