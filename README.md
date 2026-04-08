# 卡片记账系统

双人/多人卡片买卖记账工具，支持 Android APP 和 iOS/Web 网页端。

## 功能

- 批次管理：添加、删除批次，设置汇率和面值
- 卖卡：选择卡片标记售出，支持坏卡标记（含余额）
- 查卡：查看剩余卡片，组合凑面值，一键提卡
- 结算：按人汇总销售，清账功能
- 多端同步：通过 GitHub API 实现数据同步，无需 VPN

## 项目结构

```
flutter_app/    # Flutter 源码（Android + Web）
web-dist/       # 编译好的 Web 版本（部署到 GitHub Pages）
```

## 使用方式

- **iOS / 电脑浏览器**：访问 https://hhhsl123.github.io/card-book-app/
- **Android APP**：从 [Releases](https://github.com/hhhsl123/card-book-apk/releases) 下载 APK

## 开发

```bash
cd flutter_app
flutter pub get
flutter run -d chrome    # Web 调试
flutter run              # Android 调试
flutter build web --release --base-href "/card-book-app/"
flutter build apk --release
```
