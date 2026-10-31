# Cognate for LazyCat

Cognate 服务端的 LPK v2 Exec 打包仓库，仅发布喵喵商店，官方商店关闭。

- 包名：`community.lazycat.app.cognate`，新应用默认 `community.lazycat.app` 前缀。
- 当前候选：`0.1.0-rc.6`，最低 lzcos `1.6.2`，目标 Linux amd64。
- 源码：`upstream.env` 固定上游 tag 和完整 commit；不从浮动 main 构建。
- 构建：Go `1.27.3`、Node `26.12.0`、`CGO_ENABLED=0`，Web 嵌入服务端，不依赖 Docker。
- 运行：`exec://8080` 仅监听 loopback，数据和密钥持久保存在 `/lzcapp/var/cognate`，不写应用文稿。

## 账号与数据

安装向导提供首次管理员用户名、secret 密码、已有管理员账号 UUID、OIDC 开关与 GitHub OAuth 公开 client ID。空实例默认创建 `admin`，密码由平台随机生成，安装前请保存。升级保持用户名不变；更改安装密码不会重置已有账号，原密码仍有效。已有用户但没有初始化记录时，请清空首次用户名并填写原账号 UUID；不会自动提权普通账号。管理员沿用全局日志管理权限，不可读取其他用户的私有技能或凭据。

初始化密码经 `0600` 私有文件交给服务端，不进入 argv、子进程环境或日志；`keys/bootstrap.secret` 是受限的安装输入文件。重启已有初始化记录时不读取该文件，删除输入文件也不影响原密码。关闭 OIDC 时保留本地登录且不调用平台 discovery；开启时仍需平台注入的完整 OIDC 参数。

使用平台注入的 `LAZYCAT_AUTH_OIDC_ISSUER_URI`、client ID 和 client secret，接入上游既有标准 OIDC discovery；回调为 `/auth/oidc/callback`，不信任外部身份头。保留 Cognate 本地账号，已有账号须显式绑定 OIDC，不按邮箱合并。

启动脚本显式传递 `--data-dir /lzcapp/var/cognate/data`、`--key-file /lzcapp/var/cognate/keys/master.key` 和 `--init-key-if-missing`，不再使用 shell 命令生成主密钥。服务端只为无数据的新实例生成 32 字节随机密钥，升级保留原密钥；已有数据但丢失密钥时拒绝重新生成。OIDC secret 经私有文件传给进程，不放入命令参数或日志。请备份整个私有数据目录和原主密钥，丢失主密钥无法解密已有凭据。卸载前另行备份，不能依赖卸载保留内部状态。

状态目录创建后转换为物理规范路径，以兼容祖先挂载路径别名；仍拒绝 key/data 叶节点符号链接，不覆盖或放宽已有主密钥的大小、权限和所有权检查。`root` 是合法运行身份，不因 UID 0 拒绝。

用户 rc.5 真机日志显示密钥 `0600`、UID 0、32 字节、单硬链接，但应用卷祖先为无 sticky bit 的 `0777`，触发严格路径校验。官方 SDK 的 `docs/app-runtime.md` 将 `/lzcapp/var` 定义为该应用的备份数据目录，`docs/other.md` 给出应用所属用户与 `0700` 的权限约定。rc.6 仅在使用 `/lzcapp/var` 下的状态路径时检查固定应用卷为当前用户拥有的真实目录，然后将该卷收紧至 `0700`；不递归 chown、不修改 `/lzcapp`、文稿或其他平台目录，不调整自定义外部状态路径的祖先。只读、符号链接或非当前用户拥有的卷明确拒绝。

本地使用独立 user/mount/network namespace，以 UID 0 和 `0777` 的 `/lzcapp/var` 复现旧拒绝；修正后的实际二进制及原始包装脚本 health 200，显式目录参数、初始管理员授权、升级后原密码和密钥、重新放宽卷权限后的重启均通过。符号链接/只读卷、自定义外部不可信祖先、公开权限/多硬链接密钥和已有数据库丢密钥均拒绝。隔离环境验证不等于懒猫真机安装或平台 OIDC 验收。

当前是服务端预览包，不包含 CLI 或桌面 GUI。完整云备份/恢复、全部 agent 配置应用与 Pack 自动应用未完成，见[上游 TODO](https://github.com/ca-x/cognate/blob/2bb9b137e124a89833d3c66f1c59018d7e8e44c5/docs/TODO.md)。懒猫真机部署、平台 OIDC 和手机文件选择器仍须实测，不将构建成功称作真机验收或官方商店合规。

## 自动构建与发布

使用 `ca-x/lazycat-github-action` 的 reusable workflow，版本来源为 Git。推送与 `package.yml` 一致的 `vX.Y.Z`（可含 rc 后缀）触发构建、版本化 GitHub Release Asset 和喵喵商店提交。PR 和默认手动运行仅 dry-run，不上传商店；手动发布必须明确勾选 `publish`。

LPK 输出在 `.lazycat-build/`，内容目录为 `dist/content/`，避免把包打进自身。最终文件名为 `community.lazycat.app.cognate-v<VERSION>.lpk`；商店复用经校验的 GitHub Release URL 与 SHA256，不二次构建。

仓库或授权的组织 Secrets 必须配置 `APPSTORE_URL`、`APPSTORE_TOKEN`；可选的分组代码放 `PRIVATE_STORE_GROUP_CODES`。不要把任何 Secret 值写进仓库、Issue 或日志。新仓库若使用组织 Selected repositories 策略，管理员须将本仓库加入授权；普通组织成员无法替管理员读取或修改该授权。无需官方商店 token 或镜像复制凭据。

本地构建：安装上述版本后运行 `bash build.sh`，再用 `lzc-cli project build` 或同一 GitHub Action 验证 LPK。目标架构由 `LAZYCAT_TARGET_ARCH` 控制，当前发布配置为 amd64；改为 arm64 时须同步修改 Action 配置并单独验收。

本地 CLI 打包前先执行 `mkdir -p .lazycat-build`；GitHub Action 负责创建自己的产物目录。

本地启动回归：先构建固定上游，再运行 `python3 tests/startup.py --server "$PWD/dist/content/cognate-server" --wrapper "$PWD/dist/content/run.sh"`，需要 Linux、Python 3、bubblewrap 和可用的 user namespace。测试只修改临时目录和隔离命名空间中的挂载，不修改本机 `/lzcapp`。CI 在 root 下执行同一用例，必须通过后才运行 LPK 构建及商店发布。

根目录 `npm run build` 是同一构建脚本的便捷入口；根 lockfile 为 reusable workflow 的 Node 工具链缓存提供有效输入，Web 依赖仍由固定上游的真实 lockfile 经 `npm ci` 校验。`v0.1.0-rc.1` 的首轮在 Node 缓存缺少根 lockfile 时失败，未构建 LPK、未发布商店，保留原失败与原 tag，不重写为成功。

## 首包交付记录

`v0.1.0-rc.2` 的 [Actions 41159355144](https://github.com/lazycat-contrib/cognate-lzcapp/actions/runs/41159355144) 构建及喵喵商店提交成功；[LPK 下载](https://github.com/lazycat-contrib/cognate-lzcapp/releases/tag/v0.1.0-rc.2) 为公开 prerelease，大小 67,970,048 字节，SHA256 为 `c1bb1b0eee244a8504bdb22bbc2401b97503e0e76a49430b65832f2f71381b63`。

商店响应接受应用 `670`、版本 `3752`，使用同一 GitHub Release Asset URL 和上述 SHA256；官方商店步骤未启用。此记录不声称商店前台可见或真机部署已通过。后续 rc 包发布后也须核对 GitHub prerelease 标记，不能仅凭数字版本当作正式版。

本地已通过 shell 语法、actionlint、512px 图标检查，以及隔离环境下的主密钥保留、私有权限、secret 文件交接、不进入 argv/进程环境、缺少 OIDC 与符号链接拒绝测试；真实服务端与平台身份交互仍待真机验证。

## rc.3 候选验证

上游固定 `server-v0.1.0-rc.3` / `577ed79bacce981c474fe434094115780885efa1`，全仓 Go 7,444 PASS、158 SKIP、0 FAIL，六平台/架构服务端 CGO0 编译通过。本地 `lzc-cli project lint`、actionlint、真实 LPK 构建通过；包内包含 `deploy_params.yml`，与声明逐字一致。直接从本地 LPK 提取的真实服务端通过别名路径启动、原主密钥保留、首次管理员 Login/全局日志授权，以及更换或移除密码输入文件后的两次重启检查；密码不进入 argv、子进程环境或捕获日志。

本地构建 LPK SHA256 `ec62fe0d81121987ee03b52845c05eb725f09711ae425b76601d63d9a8d5b147` 只是本地验证产物，不代表后续 CI Release 的最终字节。初次 HTTPS 源码克隆无进展后中断，改用本地临时 Git SSH 路由，不修改上游 URL；本地 CLI 需要先创建 `.lazycat-build/`。保留原失败日志，均不称产品回归。rc.3 的 CI/商店发布和用户盒子安装状态须另行核实；不将本地通过称作真机成功。

`v0.1.0-rc.3` 的 Actions `41166452977` 在构建前被 SDK 原始 Manifest 解码拒绝：整项 `{{ printf ... }}` 环境模板不能被此预检查当作普通 YAML 字符串。该 run 没有构建 CI LPK，也没有上传 GitHub Release 或商店，保留原 tag，不重写为成功。

rc.4 保留同一服务端源码，仅将安装参数改为受支持的 `KEY={{ .U.parameter | b64enc }}` 普通标量。编码只是安全穿过 YAML，不是加密；密码进入脚本后立即清除原环境变量，直接解码到私有文件，保留换行和特殊字符，不通过 shell 字符串重建密码。使用与失败 CI 一致的 Action v1.3.7 二进制取得旧模板普通 RED、新模板预检查 PASS；没有渲染带虚构参数的 Manifest。正式上传仍由新版本 run 完成，官方商店继续关闭。

## rc.4 发布与设备反馈

Actions `41166888272` 已成功，喵喵接受 app `670` / version `3753`，LPK 68,021,248 字节，SHA256 `3b1ed55b8d1bbe319aef82d2de3e330bdc8fcca4ac89eacebdae75745338f2e8`，与 GitHub Release Asset digest 一致。Release 已明确标为 prerelease，不更新 latest。官方商店关闭。

用户在 2026-10-31T04:06Z 再次报告相同主密钥校验拒绝；本地别名复现的修复没有证明解决用户设备问题。先暂停新功能，rc.5 仅增加启动元数据诊断：effective UID、密钥 mode/UID/GID/硬链接数/字节数及逐级目录元数据，不记录密钥内容或设置值、不放宽校验、不修改平台祖先目录权限。缺失密钥仍自动用系统随机源创建并检查恰好 32 字节，已有密钥绝不覆盖。rc.5 是定位设备差异的诊断候选，不声称根因已确定或真机修复完成。

rc.5 本地真实 LPK 构建、提取 binary/wrapper 一致性及完整启动回归通过。额外构造「key 32 字节/0600 但祖先目录 0777 无 sticky」和「key 硬链接数 2」两种不同原因，均被核心拒绝，诊断能区分且不含密钥内容；不把这两种构造归因于用户设备。新脚本在全新目录自动创建私有 32 字节密钥并取得真实 health 200。预览标签增加成功后的 prerelease/no-latest 自动校正，不依赖每次手动修改 Release。

rc.5 Actions `41167603186` completed/success；喵喵接受 app `670` / version `3754`，68,022,272 字节 LPK 的 SHA256 `6eda03732a17f27592ac76c9ddc0f3f0e53e1c0b393e443a73fca0b3066a5626` 与 GitHub Release Asset digest 一致。公开 prerelease，官方商店关闭。请从新启动日志回传 `Cognate storage diagnostics:` 行，无需进入应用终端；尚未收到这些设备元数据，故障仍未确认修复。
