# Dell 作为 Mac 的 USB4 扩展屏

Mac 创建独立虚拟显示器，用 [Sunshine](https://github.com/LizardByte/Sunshine) 经 USB4 传给 Dell 上的 [Moonlight PC](https://github.com/moonlight-stream/moonlight-qt)。iPad Sidecar 可同时使用。目标分辨率与 Dell 原生屏幕一致：**1920 × 1080，60 Hz**。

## 使用前准备

本仓库保存已经验证的本机配置，附带的 `bin/vdisplay` 为 Apple Silicon Mac 编译。需要先在 Mac 安装 Sunshine，在 Dell 安装 Moonlight，并完成两者配对；启动脚本使用 `/opt/homebrew/bin/python3`。Sunshine、Moonlight 安装包、配对密钥和管理密码不随本仓库上传。

另一台电脑使用时，应将两个 `.sh` 文件中的 `DELL_IP` 改为该电脑的 USB4 地址，并确认 Mac 的有线接口为 `bridge0`。

## 日常使用

1. 保持两台电脑间的 USB4 数据线连接。
2. 在 Mac 双击 `连接 Dell 扩展屏.command`。显示“Mac 端已启动”后即可关闭终端窗口，投屏程序会继续运行。
3. 在 Dell 打开 Moonlight，选择已配对的 Mac，然后打开 `Desktop`。
4. 用完后在 Mac 双击 `断开 Dell 扩展屏.command`。下次使用时重复第 2、3 步。

这是 Sunshine/Moonlight 方案，Dell 不会出现在 macOS 原生“屏幕镜像”设备列表中。

如果系统“显示器”或“屏幕镜像”列表里出现 Dell 的名称（例如 ZH2022），那是之前 AirServer 提供的 AirPlay 连接。在这台 Mac 上通过该入口连接 Dell 曾使 iPad Sidecar 断开。需要同时使用 iPad 和 Dell 时，系统显示器里连接 iPad；Dell 则在 Moonlight 中打开 Desktop。`Dell Virtual` 是本方案生成的本地扩展显示器。

## 已完成的配置

- Sunshine `2026.914.233613` 安装在 `/Applications/Sunshine.app`；已核对官方发布文件摘要、开发者签名与 Apple 公证。
- Dell 已安装 Moonlight PC `6.1.0`，并通过 USB4 地址与 Mac 配对。
- `bin/vdisplay` 来自 MIT 许可的 [vdisplay](https://github.com/pacifistazero/vdisplay)，固定在提交 `0ce57c9c053cd918836098be8087d72b4775214f`。本地源码仅增加一次 stdout 刷新，让启动脚本读到显示器 ID。该项目使用 macOS 私有的 `CGVirtualDisplay` API。
- Dell 的 USB4 地址是 `169.254.118.3`；脚本每次从 Mac 的 `bridge0` 读取本机地址。
- Sunshine 管理密码保存在只有当前用户可读的 `.run/web-credentials.txt`。运行时配置和日志位于 `/private/tmp/dell-display-<Mac 用户 ID>/`；启动命令每次选择新的虚拟屏 ID，并限制 Sunshine 只监听 Mac 的 USB4 地址。

## 命令行使用与重建

也可在此目录运行 `./start-dell-display.sh` 和 `./stop-dell-display.sh`。启动命令返回后投屏程序继续运行，停止时必须执行关闭命令。

首次实测：Dell 收到独立的 1920×1080、约 60 FPS 扩展桌面；Moonlight 显示网络丢帧 0%，平均网络延迟约 1 ms，同时 Mac 仍列出 iPad Sidecar。实际使用体验可随窗口内容和机器负载变化。

To rebuild the virtual-display binary from the vendored source:

```sh
cd vdisplay-src
XDG_CACHE_HOME=/tmp/dell-swift-cache CLANG_MODULE_CACHE_PATH=/tmp/dell-clang-cache swift build -c release --disable-sandbox --scratch-path /tmp/dell-vdisplay-build
```

vdisplay 依赖 macOS 私有 API，未来系统更新后可能需要重建或调整。
