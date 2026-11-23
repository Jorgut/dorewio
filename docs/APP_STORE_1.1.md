# App Store 1.1 — screenshots & What's New (draft)

Draft date: 2026-11-23 · build **1.1 (19)** · branch `release/1.1` · **not uploaded**.

## What's New（简体中文，草稿）

```text
新增 PDF 谱架：从「文件」导入 PDF 曲谱，离线翻看，支持连续滚动、双指缩放和翻页。
支持 iPad：大屏上居中排版，课程、指板、调音和 PDF 阅读都适配。
深色模式对比度优化，夜间练习更清楚。
修复若干细节问题，提升稳定性。
```

> 若 1.1 同时提交 Pro 内购，补充一句「dorewio Pro 一次买断，解锁进阶训练与完整曲目功能」，并以实际构建为准。

## 截图顺序（1320 × 2868，5 张）

| # | 文件 | 画面 | 建议文案 |
|---|---|---|---|
| 1 | `docs/screenshots/app-1.1/01_today.png` | 今天 | 每天 10 分钟，有琴没琴都能练 |
| 2 | `docs/screenshots/app-1.1/02_learn.png` | 学习 | 没带琴，也能完成一节有效短课 |
| 3 | `docs/screenshots/app-1.1/03_train.png` | 训练 | 调音、节奏、运弓、揉弦，一项项练 |
| 4 | `docs/screenshots/app-1.1/04_pdf_shelf.png` | 曲目 · PDF 谱架（1.1 新） | 把老师发的 PDF 谱带进来 |
| 5 | `docs/screenshots/app-1.1/05_pdf_reader.png` | PDF 阅读器（1.1 新） | 离线翻谱，双指缩放，不上传 |

## iPad 截图（2064 × 2752，5 张）

`TARGETED_DEVICE_FAMILY = "1,2"` 后 App Store 会要求 iPad 截图；先用 iPad Pro 13-inch (M5) 模拟器草稿：

| # | 文件 | 画面 |
|---|---|---|
| 1 | `docs/screenshots/app-1.1/ipad/01_today.png` | 今天 |
| 2 | `docs/screenshots/app-1.1/ipad/02_learn.png` | 学习（两栏：课程 + 训练） |
| 3 | `docs/screenshots/app-1.1/ipad/03_train.png` | 训练（两栏：基础 + 技巧） |
| 4 | `docs/screenshots/app-1.1/ipad/04_pdf_shelf.png` | 曲目 · PDF 谱架 |
| 5 | `docs/screenshots/app-1.1/ipad/05_pdf_reader.png` | PDF 阅读器 |

备用：`06_lesson.png`（第一课）、`07_fingerboard.png`（第一把位），可作为第 6–7 张。

## 提交前必须处理

1. **重拍**：当前 5 张是模拟器草稿，`Dynamic Island` 在部分画面中显示不一致（有的有黑条、有的没有）；正式上传前用同一台 iPhone 16 Pro Max（iOS 26.5）重拍一轮。
2. **换真实谱面**：阅读器截图里的 PDF 是测试用空五线谱（页眉写着「预览乐谱」），正式版要换成一份真实曲谱 PDF，且不出现个人信息。
3. **尺寸复核**：6.9"/6.7" 用 1320×2868；iPad 用 2064×2752（iPad Pro 13"）。如 ASC 要求 12.9" 套装，另出 2048×2732。
4. **文案一致**：What's New 必须与实际 build 19 功能一致；Pro 若未随 1.1 提交，不要提内购。
5. **顺序**：第一张放「今天」或「PDF 谱架」二选一；建议把新功能放第 1 或第 4 张，避免用户划不到。
6. **iPad 方向**：当前内容在 iPad 横屏时也是居中窄栏，没有专门的横屏双栏布局；提交前至少在 iPad 横屏和分屏下各过一遍，确认不被裁切。

## 截图来源命令（模拟器）

```bash
# 需要先安装 1.1 构建并写入测试 PDF 索引
xcrun simctl launch <UDID> com.archintera.VibratoCoach -tab 0   # 今天
xcrun simctl launch <UDID> com.archintera.VibratoCoach -tab 1   # 学习
xcrun simctl launch <UDID> com.archintera.VibratoCoach -tab 2   # 训练
xcrun simctl launch <UDID> com.archintera.VibratoCoach -tab 3   # 曲目 / PDF 谱架
xcrun simctl launch <UDID> com.archintera.VibratoCoach -pdfViewerPreview  # PDF 阅读器
xcrun simctl io <UDID> screenshot out.png
```

`-tab` 与 `-pdfViewerPreview` 仅在 `DEBUG` 构建中生效。
