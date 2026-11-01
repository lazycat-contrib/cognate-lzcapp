# Cognate for LazyCat

Cognate 服务端的 LPK v2 Exec 打包仓库，仅发布喵喵商店，官方商店关闭。

- 包名：`community.lazycat.app.cognate`，新应用默认 `community.lazycat.app` 前缀。
- 当前正式分发：`0.1.0`，最低 lzcos `1.6.2`，目标 Linux amd64；GitHub Release 与喵喵商店已发布。
- 源码：`upstream.env` 固定上游 tag 和完整 commit；不从浮动 main 构建。
- 构建：Go `1.27.3`、Node `26.12.0`、`CGO_ENABLED=0`，Web 嵌入服务端，不依赖 Docker。
- 运行：`exec://8080` 仅监听 loopback，数据和密钥持久保存在 `/lzcapp/var/cognate`，不写应用文稿。

## 0.2.0 发布准备

本次固定 `server-v0.2.0` / `71afc524d35efeb3253160dce41a26d12a3c9a4b`，
增加固定 Gemini profile 的服务端配置授权、Linux 离线归档校验及合法空 WAL 索引的
备份检查修正。LPK 新增 Gemini 原版 LICENSE 和完整第三方声明，保留 Codex 许可。
不包含 GUI、CLI 安装包，也不包含仍在开发的完整恢复、Pack 自动配置或 MyGo 本机应用。

`v0.2.0` 需等待上游服务端发布门、固定源码构建、隔离启动及实际 LPK 内容核验通过后
才发布；本段不预先宣称商店交付成功。原管理员密码、主密钥和私有数据路径保持不变。
平台 OIDC 和真机升级数据保留仍需用户测试。以下旧版回执保持原有范围。

## 0.1.0 分发边界

本版正式分发已有的 Skill 聚合、分发与同步服务，包含内嵌 Web、本地账号、显式 OIDC 绑定及应用私有数据与密钥保护；不包含 CLI 或桌面 GUI。正式分发已有能力不等于全产品完成，也不代表全平台 GA。

完整备份恢复、全部 agent 配置及 Pack 自动应用、跨平台验收仍待完成；平台 OIDC、手机文件选择器与真机升级仍待验证。用户已反馈 rc.7 安装成功，仅覆盖该版本在该设备的安装，不替代 `0.1.0` 最终资产、平台 OIDC 或用户数据升级验收。

本版构建固定 `server-v0.1.0` / `9d2070a1ae9c51e7e2710ec74970582e1d6c561c`。发布须先通过上游 server release 门禁及本仓库启动与 LPK 检查，并获得发布 go，之后才创建 `v0.1.0`；本版已完成这些步骤，正式分发回执见页末。以下 rc 历史保留原始成功、失败与当时未覆盖项，不作为本版新增验收。

## 账号与数据

安装向导提供首次管理员用户名、secret 密码、已有管理员账号 UUID、OIDC 开关与 GitHub OAuth 公开 client ID。空实例默认创建 `admin`，密码由平台随机生成，安装前请保存。升级保持用户名不变；更改安装密码不会重置已有账号，原密码仍有效。已有用户但没有初始化记录时，请清空首次用户名并填写原账号 UUID；不会自动提权普通账号。管理员沿用全局日志管理权限，不可读取其他用户的私有技能或凭据。

初始化密码经 `0600` 私有文件交给服务端，不进入 argv、子进程环境或日志；`keys/bootstrap.secret` 是受限的安装输入文件。重启已有初始化记录时不读取该文件，删除输入文件也不影响原密码。关闭 OIDC 时保留本地登录且不调用平台 discovery；开启时仍需平台注入的完整 OIDC 参数。

使用平台注入的 `LAZYCAT_AUTH_OIDC_ISSUER_URI`、client ID 和 client secret，接入上游既有标准 OIDC discovery；回调为 `/auth/oidc/callback`，不信任外部身份头。保留 Cognate 本地账号，已有账号须显式绑定 OIDC，不按邮箱合并。

启动脚本显式传递 `--data-dir /lzcapp/var/cognate/data`、`--key-file /lzcapp/var/cognate/keys/master.key` 和 `--init-key-if-missing`，不再使用 shell 命令生成主密钥。服务端只为无数据的新实例生成 32 字节随机密钥，升级保留原密钥；已有数据但丢失密钥时拒绝重新生成。OIDC secret 经私有文件传给进程，不放入命令参数或日志。请备份整个私有数据目录和原主密钥，丢失主密钥无法解密已有凭据。卸载前另行备份，不能依赖卸载保留内部状态。

状态目录创建后转换为物理规范路径，以兼容祖先挂载路径别名；仍拒绝 key/data 叶节点符号链接，不覆盖或放宽已有主密钥的大小、权限和所有权检查。`root` 是合法运行身份，不因 UID 0 拒绝。

用户 rc.5 真机日志显示密钥 `0600`、UID 0、32 字节、单硬链接，但应用卷祖先为无 sticky bit 的 `0777`，触发严格路径校验。官方 SDK 的 `docs/app-runtime.md` 将 `/lzcapp/var` 定义为该应用的备份数据目录，`docs/other.md` 给出应用所属用户与 `0700` 的权限约定。rc.6 仅在使用 `/lzcapp/var` 下的状态路径时检查固定应用卷为当前用户拥有的真实目录，然后将该卷收紧至 `0700`；不递归 chown、不修改 `/lzcapp`、文稿或其他平台目录，不调整自定义外部状态路径的祖先。只读、符号链接或非当前用户拥有的卷明确拒绝。

本地使用独立 user/mount/network namespace，以 UID 0 和 `0777` 的 `/lzcapp/var` 复现旧拒绝；修正后的实际二进制及原始包装脚本 health 200，显式目录参数、初始管理员授权、升级后原密码和密钥、重新放宽卷权限后的重启均通过。符号链接/只读卷、自定义外部不可信祖先、公开权限/多硬链接密钥和已有数据库丢密钥均拒绝。隔离环境验证不等于懒猫真机安装或平台 OIDC 验收。

完整功能与剩余范围见[本版上游 TODO](https://github.com/ca-x/cognate/blob/9d2070a1ae9c51e7e2710ec74970582e1d6c561c/docs/TODO.md)。不将构建成功、商店接受或 rc.7 安装反馈称作本版真机升级验收或官方商店合规。

## 自动构建与发布

使用 `ca-x/lazycat-github-action` 的 reusable workflow，版本来源为 Git。推送与 `package.yml` 一致的 `vX.Y.Z`（可含 rc 后缀）触发构建、版本化 GitHub Release Asset 和喵喵商店提交。PR 和默认手动运行仅 dry-run，不上传商店；手动发布必须明确勾选 `publish`。

LPK 输出在 `.lazycat-build/`，内容目录为 `dist/content/`，避免把包打进自身。最终文件名为 `community.lazycat.app.cognate-v<VERSION>.lpk`；商店复用经校验的 GitHub Release URL 与 SHA256，不二次构建。

仓库或授权的组织 Secrets 必须配置 `APPSTORE_URL`、`APPSTORE_TOKEN`；可选的分组代码放 `PRIVATE_STORE_GROUP_CODES`。不要把任何 Secret 值写进仓库、Issue 或日志。新仓库若使用组织 Selected repositories 策略，管理员须将本仓库加入授权；普通组织成员无法替管理员读取或修改该授权。无需官方商店 token 或镜像复制凭据。

本地构建：安装上述版本后运行 `bash build.sh`，再用 `lzc-cli project build` 或同一 GitHub Action 验证 LPK。目标架构由 `LAZYCAT_TARGET_ARCH` 控制，当前发布配置为 amd64；改为 arm64 时须同步修改 Action 配置并单独验收。

本地 CLI 打包前先执行 `mkdir -p .lazycat-build`；GitHub Action 负责创建自己的产物目录。

本地启动回归：先构建固定上游，再运行 `python3 tests/startup.py --server "$PWD/dist/content/cognate-server" --wrapper "$PWD/dist/content/run.sh"`，需要 Linux、Python 3、bubblewrap 和可用的 user namespace。测试只修改临时目录和隔离命名空间中的挂载，不修改本机 `/lzcapp`。CI 在 root 下执行同一用例，必须通过后才运行 LPK 构建及商店发布。

rc.6 的 CI `41171336131` 在 namespace 挂载 runner checkout 中的测试脚本时报告 `Permission denied`，尚未进入应用启动或商店发布；保留失败 tag，不移动、不重试绕过门禁。rc.7 将测试脚本与二进制一样复制到本轮测试用户拥有的临时目录后再挂载，不修改 runner home 权限或应用检查。应用修正逻辑与上游固定版本不变。

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

## rc.7 私有卷修正交付

随后收到的 rc.5 真机诊断已确认密钥本身合规，但第二级祖先无 sticky bit、权限 `0777`，与本地拒绝条件一致。rc.6 引入本页描述的应用私有卷修正和程序内密钥初始化；其 CI `41171336131` 被测试脚本挂载权限问题拦下，未上传商店。rc.7 只修正测试脚本暂存路径，不放宽应用检查，保留 rc.6 失败和 tag。

包装源码 `58256406a2bf003fe97248cc2bbc6d1a64b044a0`，固定上游 `server-v0.1.0-rc.4` / `a576aeb5c8adf4bda98c1431bcd6072c642d3660`。Actions `41171750570` completed/success，root 隔离启动门禁、LPK 发布和预览标记全部通过。服务端对应发布 run `41170966158` 也 success，含双架构 Docker 和实际镜像验证。

最终 GitHub 公开 prerelease 的 `community.lazycat.app.cognate-v0.1.0-rc.7.lpk` 为 68,036,096 字节，SHA256 `047ea3a9d71029470a086fd91316eed39f531dbae0399b8b5d7ecdfb114b29c1`。喵喵接受 app `670` / version `3757`，published=true、skipped=false，使用相同 GitHub Release Asset URL 和上述 SHA256；官方商店关闭。升级不改变数据与密钥路径，不迁移已有 key 或数据库。

本地另行构建的 rc.7 LPK 为 68,036,608 字节，SHA256 `205ef24ed2883a5856a038310abffb1b3fcc8fde304016a1a071abf7ea512e93`；其解包二进制与脚本一致性、完整 namespace 回归通过，不把本地字节冒称为 CI 最终资产。当时真机安装、平台 OIDC 与用户数据升级仍待验证；现已收到用户 rc.7 安装成功反馈，平台 OIDC 与用户数据升级仍无完整实测结论。

最终 Release Asset 下载探针在 90 秒超时退出（exit 124），只有部分字节，没有完成下载、重新计算最终文件 SHA256 或启动最终 CI LPK。最终身份以 GitHub API digest 与商店回执一致性核对；不要把本地实包和 CI 构建后的启动通过当作最终下载验证。

## 0.1.0 正式分发回执

包装提交 `4c7df600a3425f0281c07094fadd4a7245714a69`，annotated tag `v0.1.0`；上游仍固定上述 `server-v0.1.0` 完整 commit，不跟随后继主线。上游 server release `41276592652` completed/success 后才发布 LPK 标签。

本仓 Actions `41278328477` completed/success：`startup-smoke` job `124764948137` 与 `lazycat / lazycat` job `124765288335` 均成功。喵喵发布步骤成功，官方商店步骤和预览标记 job 按配置跳过；只触发这一次标签发布，没有手动重复上传。

GitHub Release `430390425` 为公开正式版（non-draft、non-prerelease），最终资产 `community.lazycat.app.cognate-v0.1.0.lpk`，77,757,952 字节，SHA256 `5e03f8025575162f1a63b357ed76e43f983a30bce3005f1954ec749478009d91`。喵喵返回 app `670` / version `3838`、published=true、skipped=false，使用同一 Release Asset URL 和 SHA256；官方商店仍关闭。

最终 CI 资产经官方 API 完整分片下载并重新计算整体 size/SHA256，与 Release digest 和商店回执一致。解包确认包名、版本、运行 Manifest、部署参数、原 wrapper、源 commit、许可证及 Linux amd64 / Go1.27.3 / CGO0 / 干净 VCS 元数据；解包后的真实最终二进制通过完整六场景 namespace 启动回归。普通 Release URL 下载低速，仅取得部分字节后停止，不将其称为完整普通 URL 下载验证。

启动测试仅迁移了丢主密钥时的精确 runtime 双行拒绝协议，仍要求非零退出、不重建 key，并新增原 SQLite bytes/device/inode 不变检查。旧断言 RED 保留；build、解包与最终下载内容完整回归通过，任意其他错误、零退出、重建 key、数据库字节或身份变化等负控均被拒绝。没有修改安全 wrapper、参数或服务端源码。

这是已有能力的正式分发，不是全产品完成或全平台 GA。`0.1.0` 真机安装与用户数据升级、平台 OIDC 仍待实际验证，其余范围继续遵守本页分发边界。
