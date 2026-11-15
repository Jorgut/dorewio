# dorewio 中国区 ICP 备案豁免申请材料

日期：2026-11-15

> 这是 App Store 层面的 ICP 备案豁免（不是向工信部备案）。适用于**纯离线、无自建服务器/账号/UGC/广告/第三方统计 SDK**的独立 App。
> 社区实测流程：先通过 Apple Developer Contact Us 提交请求 → Apple 回复要求签字声明 → 上传签字扫描件 → Apple 批准后国区可用。通常 1–4 个工作日。

## 0. 事实核对（申请前确认）

| 项 | 值 |
|---|---|
| App 名称 | dorewio |
| App 的 Apple ID | 6827607435 |
| Bundle ID | com.archintera.VibratoCoach |
| Team ID | GB38532D8G |
| 开发者账号 | Jorgut / archintera |
| 账户持有人 | 以 Apple Developer 账号显示为准（当前疑似 Hongliang Zhu / 朱红亮） |
| 是否有自建后端 | 无 |
| 是否有账号/登录 | 无 |
| 是否有 UGC/社区/评论 | 无 |
| 是否有广告/统计/第三方 SDK | 无 |
| 数据存储 | 全部本地（练习记录、录音、导入乐谱） |
| 网络访问 | 无自建 API；仅 Apple 系统服务（如未来 StoreKit 内购） |
| 当前版本内购 | 无（1.0 全部功能免费） |

## 1. 第一步：Contact Us 提交请求（现在就可以发）

入口：<https://developer.apple.com/cn/contact/> → 拉到页面底部 → **联系我们**

选择路径：

1. **新的问题**
2. 主题：**分发**（或 **App 审核**）→ **有关 App 审核的其他疑问**
3. 按下文填写

### 英文文案（直接粘贴）

> Subject: Request for ICP filing exemption — dorewio (offline app)
>
> Hello Apple Developer Support,
>
> I would like to request an exception from the ICP filing requirement for distribution in mainland China for my app **dorewio**.
>
> - App name: dorewio
> - App Apple ID: 6827607435
> - Bundle ID: com.archintera.VibratoCoach
> - Team ID: GB38532D8G
>
> The app is a standalone offline application: there is no account or login, no self-hosted server or API, no user-generated content, community or comments, and no advertising or third-party analytics SDKs. All practice data, recordings and imported scores are stored locally on the device. The only optional network access is Apple's own StoreKit for a future one-time purchase; the current build offers no in-app purchases.
>
> As a pure standalone app it does not provide internet information services, so I would like to request an exception from the App Store ICP filing requirement for mainland China.
>
> Thank you.

### 中文简版（如果表单项只接受中文）

> 您好，我为我的 App **dorewio**（App ID 6827607435，Bundle ID com.archintera.VibratoCoach，Team ID GB38532D8G）申请中国大陆 App Store 的 ICP 备案豁免。该 App 为纯离线单机应用：无账号/登录、无自建服务器或 API、无用户社区/评论/UGC、无广告或第三方统计 SDK，练习记录、录音和导入乐谱全部存储在本机。除 Apple 自身服务（如未来一次性内购）外无网络访问，当前版本无内购。根据相关法规，纯单机应用不属于互联网信息服务，申请豁免 ICP 备案。谢谢。

提交后会得到一个 **case number**，保存好。

## 2. 第二步：Apple 回复后，提交签字声明

Apple 通常会回复要一封签字信，要求包含：

- Team ID 和账户持有人法定姓名
- App ID
- 账户持有人签名 + 正楷法定姓名
- 声明：为这个独立 App 申请例外、已了解相关法规、如虚假陈述愿承担法律责任

### 签字声明模板（打印后手写签名）

```
To: Apple App Review / Apple Developer Support
Re: ICP filing exemption request — dorewio

Date: ____________________

Team ID: GB38532D8G
App ID: 6827607435
Bundle ID: com.archintera.VibratoCoach
App name: dorewio

I, ______________________________ （正楷法定姓名 / printed legal name）,
the account holder of the Apple Developer account for the above app,
hereby declare that:

1. dorewio is a standalone, offline application. It does not operate or connect
   to any self-hosted server, API, cloud service, or backend infrastructure.
2. It has no user accounts or login, no user-generated content, no community,
   comments, or social features.
3. It contains no advertising SDKs and no third-party analytics or tracking SDKs.
4. All practice data, recordings and imported scores are stored locally on the
   user's device.
5. Its only optional network access is Apple's own system services (for example,
   StoreKit for a future one-time in-app purchase); the current version offers
   no in-app purchases.
6. I am requesting an exception from the ICP filing requirement for distribution
   of this independent app in mainland China. I understand the relevant laws and
   regulations and agree to bear all legal responsibility for any false statement.

Signature: ______________________________
（请使用护照备注页上的外文签名 / signature as on passport observation page）

Printed legal name: ______________________________
（正楷，例如 Hongliang Zhu（朱红亮））

Title: Account holder
```

### 签名和上传要点

- **必须手写签名**：打印 → 签名 → 扫描成 PDF（或高清照片）
- 推荐同时写中文名和拼音：`Hongliang Zhu（朱红亮）`
- 签名用你护照备注页上的外文签名即可，不需要中文签名
- Apple 会通过邮件给一个**安全上传链接**；上传后回复该邮件
- 如果 Apple 要求身份证明：附护照主页（拼音姓名）+ 备注页（外文签名）

## 3. 常见问题

### 现在可以发吗？

**可以。** 第一步 Contact Us 现在就能提交，不需要等 1.0 审核通过。签字声明是 Apple 回复后才需要，所以不用现在签。

### 需要中文还是英文？

英文即可；签名可用护照外文签名。姓名处建议中英并列。

### 需要先有官网/域名/服务器吗？

不需要。豁免就是针对无自建服务的离线 App。

### 豁免后能收费吗？

可以。使用 Apple StoreKit 的内购/付费下载通常仍符合豁免条件（联网只连 Apple 服务）；但如果以后加账号、云同步、社区、AI 在线服务或第三方 SDK，豁免会失效。

### 如果 Apple 不批怎么办？

备选是走“单机应用备案”（找省内通信管理局/接入商确认是否受理无服务器/无域名的单机 App），拿到备案号后填入 App Store Connect。成本更高、周期更长。

## 4. 提交后的跟踪清单

- [ ] Contact Us 已提交，记录 case number：__________
- [ ] 收到 Apple 回复邮件（要求声明）
- [ ] 打印声明、手写签名、扫描 PDF
- [ ] 上传到 Apple 安全链接
- [ ] 回复邮件确认
- [ ] 收到豁免确认
- [ ] App Store Connect → Pricing and Availability → 勾选中国大陆
- [ ] 确认国区可搜索/可下载

## 5. 参考

- Apple App 信息 ICP 说明：<https://developer.apple.com/cn/help/app-store-connect/reference/app-information/app-information/>
- 社区实测：<https://global.v2ex.co/t/1232582>
- 离线 App 豁免全过程：<https://bryantchen.cc/zh/posts/apple-icp-exemption-offline-app>
