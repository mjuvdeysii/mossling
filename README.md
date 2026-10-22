# Mossling 苔生

0–3 岁早教活动规划：按月龄看孩子的发展、选玩法、安排每周的教具架。原生安卓应用（Kotlin · Jetpack Compose · Material 3）。

- **今天**：月龄、今天适合一起做的一件事、一键记录、距上次喂奶和醒来多久。
- **成长**：拨动串珠翻到任意月龄；六个发展领域、可以留意的表现、玩法、接种与儿保。
- **手帐**：计时（通知栏可暂停、结束）、补记、统计、生长曲线（WHO 儿童生长标准）。
- **我的**：伙伴 Moss / Otto、设置、导出与导入记录文件、参考专题与全部来源。

不收集任何数据，所有记录只在手机上；联网只用于用户主动点的「检查更新」，详见 [PRIVACY.md](PRIVACY.md)。

## 构建

本地：`gradle :app:assembleDebug`（Gradle 8.9、JDK 17、Android SDK 35）。

CI（`.github/workflows/`）：
- `build.yml`：单元测试、Paparazzi 截图（推送到 `screens` 分支）、签名的 release APK。`VERSION` 里写的是下一个版本号：main 上若还没有对应的 `v<版本>` 发布，这次构建就作为该正式版本发布（附 `RELEASE_NOTES.md`）；之后的推送发布预发布版 `preview`。
- `emulator.yml`：构建成功后在安卓模拟器上运行关键路径 UI 测试、数据库迁移测试和冷启动计时。

签名密钥不在仓库中，来自 GitHub Secrets `HB_KEYSTORE_B64` 与 `HB_KEYSTORE_PASSWORD`。

## 内容

`app/src/main/assets/content.json` 由 `tools/export_content.py` 从手册原稿生成；`who_growth.json` 由 `tools/export_who.py` 生成；`legacy_map.json` 由 `tools/legacy_map.py` 生成。开发计划见 [PLAN.md](PLAN.md)，商店信息见 [store/listing.md](store/listing.md)。
