# Tautomation 法律文本

为 App Store 上架准备的隐私政策与用户协议草稿。**未经法务审阅前不要直接
对外发布**——尤其责任限制、争议解决、未成年人保护这几节，建议请律师过一
遍再上线。

## 文件

- [privacy-policy.md](privacy-policy.md) — 隐私政策 v1.0
- [terms-of-service.md](terms-of-service.md) — 用户服务协议 v1.0

## 提交 App Store 前要做的事

1. **替换运营方占位符**：当前使用朋友公司主体的话，把"运营方"补成
   公司全名 + 统一社会信用代码 + 备案号
2. **核对联系邮箱**：现在写的是 jack91620@gmail.com，正式上线建议改用
   公司域名邮箱（privacy@... / support@...）
3. **挂到可公开访问的 HTML 页面**：选择任一：
   - GitHub Pages（最简单）：把这两个 .md 复制到 gh-pages 分支
   - 自建静态站：放在 `api.teplanner.cloud/legal/` 路径
   - 第三方（语雀、Notion、Yuque）：可访问但需要可长期持有的链接
4. **填写 App Store Connect**：
   - App 隐私（App Privacy）问卷按本政策第 1 节如实勾选
   - 隐私政策 URL：填写步骤 3 的链接
   - 支持/服务条款 URL：同上
5. **应用内入口**：
   - 设置页 → 关于 → 隐私政策 / 用户协议（推荐添加，待实现）
   - 登录页底部小字"登录即同意《用户协议》《隐私政策》"（推荐添加）

## 应用内 SDK 与权限自查清单

提交 App Privacy 问卷时，每个第三方 SDK 都要勾选其行为。当前清单：

| SDK / 系统能力 | 用途 | 收集的数据类别 |
|---|---|---|
| Tesla Fleet API | 车辆数据 + 命令 | 精确位置、车辆使用数据 |
| 高德地图 iOS SDK | 地图渲染、POI 搜索 | 精确位置、设备 ID |
| 高德地图 Web Service | 路线规划、地理编码 | 精确位置 |
| Apple APNs | 推送通知 | 推送 token |
| 系统通知中心 | 本地通知 | 不收集 |

权限 plist 声明（已在 Info.plist / PrivacyInfo.xcprivacy）：

- 精确定位（仅当用户主动使用充电规划时申请）
- 推送通知（应用启动后请求）
- 后台运行（无，所有自动化在服务端跑）

## 修订记录

| 版本 | 日期 | 改动 |
|---|---|---|
| v1.0 | 2026-05-15 | 初版，覆盖 Tesla OAuth、AMap、APNs、删除账号入口 |
