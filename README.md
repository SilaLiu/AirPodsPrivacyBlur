# AirPods Privacy Blur

一个 macOS 隐私保护小工具：戴着支持头部运动数据的 AirPods 时，如果你转头和同事说话，电脑屏幕会自动变成毛玻璃；当你重新面向屏幕，画面会柔和地恢复清晰。

This is a small macOS prototype that uses AirPods head motion to blur your displays when you turn away from the screen.

## 功能

- 使用 AirPods 头部运动数据检测左右转头。
- 面向屏幕时保持清晰，转头超过阈值后自动模糊。
- 支持所有已连接显示器，包括外接屏。
- 毛玻璃遮罩支持淡入淡出，过渡更柔和。
- AirPods 断开或摘下后会自动退出隐私模糊。
- 遮罩为点击穿透，不影响键盘和鼠标继续操作原来的 App。
- 菜单栏常驻控制，可开始追踪、校准、测试模糊、调整灵敏度。
- 支持中文 / English，并可在应用内设置语言。
- 带应用 Logo 和圆角图标。

## 环境要求

- macOS 14 或更高版本
- 支持头部运动数据的 AirPods
- Xcode 或 Swift 工具链

## 构建

```bash
./scripts/build_app.sh
```

构建完成后会生成：

```text
dist/AirPods Privacy Blur.app
```

## 使用方法

1. 戴上支持头部运动数据的 AirPods，并连接到 Mac。
2. 构建后双击 `dist/AirPods Privacy Blur.app`，或运行：

   ```bash
   ./run_app.sh
   ```

3. 在控制窗口或菜单栏里的 `AirPods 模糊` 中操作。
4. 先点击 `测试模糊 5 秒`，确认毛玻璃遮罩能覆盖屏幕。
5. 点击 `开始 AirPods 追踪`。
6. 面向屏幕时点击 `校准正对屏幕方向`。
7. 左右转头时屏幕会自动模糊；重新面向屏幕时自动恢复清晰。

## 设置

点击菜单栏里的 `AirPods 模糊`，选择 `设置...`。

在 `语言` 下拉框中选择：

- `跟随系统`
- `中文`
- `English`

切换后界面会立即刷新。

## 重要说明

请通过 `./run_app.sh` 或 `.app` 应用包启动。不要直接运行：

```text
dist/AirPods Privacy Blur.app/Contents/MacOS/AirPodsPrivacyBlur
```

直接运行可执行文件时，macOS 可能不会正确附加 App bundle 的隐私权限元数据，导致 Motion 权限或启动行为异常。

## 当前行为

- 默认启用隐私保护。
- 支持高 / 中 / 低三档灵敏度。
- 模糊遮罩会覆盖所有已连接屏幕。
- 屏幕变更时会自动重建遮罩。
- 追踪中断、耳机断开或长时间没有运动数据时会自动清除遮罩。
- 屏幕共享时的效果取决于会议软件捕获的是整个显示器还是某个窗口。

## Notes

This project is a prototype for a privacy workflow: look at the screen to keep it readable, turn away to protect it. It is intended for local desktop privacy, not as a replacement for locking your Mac when leaving your desk.
