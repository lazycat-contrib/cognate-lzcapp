# Cognate for LazyCat

Cognate 服务端的 LPK v2 Exec 打包仓库，仅发布喵喵商店，官方商店关闭。

- 包名：`community.lazycat.app.cognate`，新应用默认 `community.lazycat.app` 前缀。
- 首包候选：`0.1.0-rc.2`，最低 lzcos `1.6.2`，目标 Linux amd64。
- 源码：`upstream.env` 固定上游 tag 和完整 commit；不从浮动 main 构建。
- 构建：Go `1.27.3`、Node `26.12.0`、`CGO_ENABLED=0`，Web 嵌入服务端，不依赖 Docker。
- 运行：`exec://8080` 仅监听 loopback，数据和密钥持久保存在 `/lzcapp/var/cognate`，不写应用文稿。

## 账号与数据

使用平台注入的 `LAZYCAT_AUTH_OIDC_ISSUER_URI`、client ID 和 client secret，接入上游既有标准 OIDC discovery；回调为 `/auth/oidc/callback`，不信任外部身份头。保留 Cognate 本地账号，已有账号须显式绑定 OIDC，不按邮箱合并。

启动脚本仅在主密钥不存在时以私有权限创建 32 字节随机密钥，升级不覆盖；OIDC secret 经私有文件传给进程，不放入命令参数或日志。请备份整个私有数据目录和原主密钥，丢失主密钥无法解密已有凭据。卸载前另行备份，不能依赖卸载保留内部状态。

当前是服务端预览包，不包含 CLI 或桌面 GUI。完整云备份/恢复、全部 agent 配置应用与 Pack 自动应用未完成，见[上游 TODO](https://github.com/ca-x/cognate/blob/2bb9b137e124a89833d3c66f1c59018d7e8e44c5/docs/TODO.md)。懒猫真机部署、平台 OIDC 和手机文件选择器仍须实测，不将构建成功称作真机验收或官方商店合规。

## 自动构建与发布

使用 `ca-x/lazycat-github-action` 的 reusable workflow，版本来源为 Git。推送与 `package.yml` 一致的 `vX.Y.Z`（可含 rc 后缀）触发构建、版本化 GitHub Release Asset 和喵喵商店提交。PR 和默认手动运行仅 dry-run，不上传商店；手动发布必须明确勾选 `publish`。

LPK 输出在 `.lazycat-build/`，内容目录为 `dist/content/`，避免把包打进自身。最终文件名为 `community.lazycat.app.cognate-v<VERSION>.lpk`；商店复用经校验的 GitHub Release URL 与 SHA256，不二次构建。

仓库或授权的组织 Secrets 必须配置 `APPSTORE_URL`、`APPSTORE_TOKEN`；可选的分组代码放 `PRIVATE_STORE_GROUP_CODES`。不要把任何 Secret 值写进仓库、Issue 或日志。新仓库若使用组织 Selected repositories 策略，管理员须将本仓库加入授权；普通组织成员无法替管理员读取或修改该授权。无需官方商店 token 或镜像复制凭据。

本地构建：安装上述版本后运行 `bash build.sh`，再用 `lzc-cli project build` 或同一 GitHub Action 验证 LPK。目标架构由 `LAZYCAT_TARGET_ARCH` 控制，当前发布配置为 amd64；改为 arm64 时须同步修改 Action 配置并单独验收。

根目录 `npm run build` 是同一构建脚本的便捷入口；根 lockfile 为 reusable workflow 的 Node 工具链缓存提供有效输入，Web 依赖仍由固定上游的真实 lockfile 经 `npm ci` 校验。`v0.1.0-rc.1` 的首轮在 Node 缓存缺少根 lockfile 时失败，未构建 LPK、未发布商店，保留原失败与原 tag，不重写为成功。

## 首包交付记录

`v0.1.0-rc.2` 的 [Actions 41159355144](https://github.com/lazycat-contrib/cognate-lzcapp/actions/runs/41159355144) 构建及喵喵商店提交成功；[LPK 下载](https://github.com/lazycat-contrib/cognate-lzcapp/releases/tag/v0.1.0-rc.2) 为公开 prerelease，大小 67,970,048 字节，SHA256 为 `c1bb1b0eee244a8504bdb22bbc2401b97503e0e76a49430b65832f2f71381b63`。

商店响应接受应用 `670`、版本 `3752`，使用同一 GitHub Release Asset URL 和上述 SHA256；官方商店步骤未启用。此记录不声称商店前台可见或真机部署已通过。后续 rc 包发布后也须核对 GitHub prerelease 标记，不能仅凭数字版本当作正式版。

本地已通过 shell 语法、actionlint、512px 图标检查，以及隔离环境下的主密钥保留、私有权限、secret 文件交接、不进入 argv/进程环境、缺少 OIDC 与符号链接拒绝测试；真实服务端与平台身份交互仍待真机验证。
