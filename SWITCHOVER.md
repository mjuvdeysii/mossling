# 切换方案：由 Mossling 原生版接替网页版应用

## 结论

原生版改用网页版的应用 ID `cn.growthhandbook.app`，用同一把签名密钥（GitHub Secrets `HB_KEYSTORE_B64` / `HB_KEYSTORE_PASSWORD`）签名，版本号大于网页版最后一个版本。已安装网页版的手机会把它当作一次普通更新直接覆盖安装，无需卸载。

**此步骤不可撤回**：覆盖安装后，网页版的界面和 WebView 存储不再可用。执行前需要项目所有者确认。

## 数据如何带过来

覆盖安装后，网页版数据仍在应用私有目录的 WebView 存储里（`app_webview/Default/Local Storage/leveldb`），但原生版不读取 LevelDB。采用两步，保证不丢数据：

1. **切换前最后一个网页版**（0.7.x）：在「记录」里提示一次「导出记录文件」，与现有导出功能相同，文件由用户保存。
2. **原生版首次启动**：若检测到 `app_webview` 目录存在且尚未导入，在「今天」顶部显示一张卡片「从旧版带过来」，点按后打开文件选择器，读取刚才导出的文件（`LegacyImport`，已实现并通过测试）。导入成功或用户关闭后，卡片不再出现。

## 执行步骤

| 步骤 | 内容 | 位置 |
| --- | --- | --- |
| 1 | `applicationId` 改为 `cn.growthhandbook.app`；`namespace` 保持 `app.mossling` | `native/app/build.gradle.kts` |
| 2 | `versionCode` 起点设为网页版最后 versionCode + 1000 | `native.yml` 中 `VERSION_CODE` |
| 3 | 网页版发布最后一版：「记录」页提示导出 | `app/` |
| 4 | 原生版加入首次启动导入卡片（检测 `app_webview`） | `ui/today` |
| 5 | Release 改为由 `native.yml` 发布正式 `v0.8.x`；`build.yml` 停止发布网页版 | `.github/workflows/` |
| 6 | 桌面小组件：网页版小组件会随更新消失，用户需重新添加原生版小组件；发布说明写明 | 发布说明 |

## 回退

若覆盖安装后发现问题，只能再发一个更高 versionCode 的修复版；无法回到网页版。因此步骤 1 之前，先用模拟器 QA（`native-qa.yml`）在装有网页版的模拟器上验证一次覆盖安装和导入流程。
