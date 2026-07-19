# 飞牛 fpk 安装包构建与发布

本仓库沿用 [shuangji66/buildbot](https://github.com/shuangji66/buildbot) 的方法，把 GitHub 上游开源应用打成飞牛 fnOS 的 `.fpk` 安装包。

GitHub Actions 每周一 04:00 UTC（北京时间 12:00）自动巡检上游 `wushuo894/ani-rss` 的最新 release，发现新版本就自动打包并上传为 artifact。

## 当前已支持的 App

| App | 上游 | 模板目录 | 工作流 |
|---|---|---|---|
| AniRSS | [wushuo894/ani-rss](https://github.com/wushuo894/ani-rss) | `fnpack/AniRSS/` | `.github/workflows/AniRSS.yaml` |

## 目录结构

```
.
├── LICENSE                                MIT
├── README.md                              本文件
├── .github/workflows/
│   └── AniRSS.yaml                        CI（schedule + workflow_dispatch）
└── fnpack/
    ├── fnpack-1.2.1-linux-amd64           官方 fnpack CLI（amd64 runner 用）
    ├── fnpack-1.2.1-linux-arm64           官方 fnpack CLI（arm64 runner 用）
    └── AniRSS/                            AniRSS 的 fpk 打包模板
        ├── manifest                       INI 风格元数据
        ├── ICON.PNG / ICON_256.PNG        桌面图标
        ├── config/{privilege,resource}    权限与资源声明
        ├── cmd/{main, install_*, ...}    9 个生命周期 bash 脚本
        ├── wizard/{install,uninstall,config}  用户表单 JSON
        ├── .last_built_version            workflow 内部状态：已打包的上游版本
        └── app/
            ├── ui/{config, images/}       桌面入口与图标
            └── app_tmp/                   CI 把 ani-rss.jar 放这里
```

## AniRSS 构建

### 触发方式

#### 自动（每周一次）

- **cron**：`0 4 * * 1`（每周一 04:00 UTC = 北京时间周一 12:00）
- **流程**：
  1. `check` job 调用 GitHub API 取 `wushuo894/ani-rss` 的 `releases/latest` tag
  2. 与 `fnpack/AniRSS/.last_built_version` 比对，相同就跳过打包
  3. 不同就触发 `build` job 下载 `ani-rss.jar`、塞进 staging、调 `fnpack build`、产出 `AniRSS-<manifest_version>-all.fpk`
  4. 上传为 artifact
  5. commit 更新 `.last_built_version`
  6. `publish` job 尝试发到 `shuangji66/FnDepot`（需要 `secrets.BUILDBOT`，缺失时优雅跳过）

#### 手动（GitHub Actions → Run workflow）

| 入参 | 必填 | 默认 | 说明 |
|---|---|---|---|
| `version` | 否 | 空（取 latest） | 上游版本号，例如 `3.1.74` |
| `manifest_version` | 否 | `${UPSTREAM}-1` | manifest 内的版本号，重发布填 `-2` / `-3` |
| `changelog` | 否 | 空（用上游 release body） | 本次更新日志 |
| `publish` | 否 | true | 是否发到 FnDepot（需要 `secrets.BUILDBOT`） |
| `force` | 否 | false | 强制构建，忽略 `.last_built_version` 对比 |
> **注意**：GitHub Actions 的 schedule 触发**不是严格的 7×24 准时**，高峰期可能延后 5–15 分钟；连续 60 天仓库无任何活动时 schedule 会被自动暂停。

### 本地构建（无需 CI）

依赖：
- Windows 版 fnpack：<https://static2.fnnas.com/fnpack/fnpack-1.2.3-windows-amd64>（Go 编译，Windows 跑得通）
- 或在 Linux runner 上用仓库自带的 `fnpack-1.2.1-linux-amd64`
- 联网

```powershell
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSCommandPath

$buildDir = Join-Path $repoRoot "work\fpk-build\AniRSS"
if (Test-Path $buildDir) { Remove-Item -Recurse -Force $buildDir }
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $repoRoot "fnpack\AniRSS\*") $buildDir

$appTmp = Join-Path $buildDir "app\app_tmp"
Remove-Item (Join-Path $appTmp ".keep") -ErrorAction SilentlyContinue
Invoke-WebRequest `
    -Uri "https://github.com/wushuo894/ani-rss/releases/download/v3.1.74/ani-rss.jar" `
    -OutFile (Join-Path $appTmp "ani-rss.jar") `
    -UseBasicParsing

$manifest = Join-Path $buildDir "manifest"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$content  = [System.IO.File]::ReadAllText($manifest)
$content  = $content.Replace('${VERSION}',   '3.1.74-1')
$content  = $content.Replace('${CHANGELOG}', '"首次发布 (基于上游 v3.1.74)"')
[System.IO.File]::WriteAllText($manifest, $content, $utf8NoBom)

& "$repoRoot\fnpack\fnpack-1.2.3-windows-amd64.exe" build --directory $buildDir
Move-Item -Force `
    (Join-Path $buildDir "AniRSS.fpk") `
    (Join-Path $repoRoot "AniRSS-3.1.74-1-all.fpk")
```

## 发布到 FnDepot（可选）

要让 schedule 自动构建后自动发布到飞牛 fnDepot 索引仓库，需要：

1. 在 GitHub 创建 `shupian35/FnDepot` 仓库，根目录放 `fnpack.json`（可用 `echo '{}' > fnpack.json` 初始化）
2. 生成一个 PAT（`Settings → Developer settings → Personal access tokens → Fine-grained tokens`），scope 选 `contents: write`
3. 在 `shupian35/bulidfpk` 仓库 `Settings → Secrets and variables → Actions → New repository secret`，名字叫 `BUILDBOT`，值填 PAT
4. 之后每周一 schedule 跑完后，会自动 commit `shupian35/FnDepot/fnpack.json` 的 `.AniRSS.{version,changelog,download_url}`

> 想改成自己的 `shupian35/FnDepot`，把 `.github/workflows/AniRSS.yaml` 里所有 `shuangji66/FnDepot` 替换掉即可。

## fnpack CLI 来源

`fnpack-1.2.1-linux-{amd64,arm64}` 是飞牛官方打包工具的 Linux 版本（Go 编译），源自 `git.teiron-inc.cn/appcenter/`，仅用于 `fnpack build <AppName>` 把模板目录打成 `.fpk`。

子命令：
- `fnpack build [-d <dir>]`：打 fpk
- `fnpack create <appname> [-t native|docker] [-w]`：脚手架
- `fnpack verify`：校验

## 参考

- 上游应用：<https://github.com/wushuo894/ani-rss>
- 上游 release：<https://github.com/wushuo894/ani-rss/releases>
- fnOS 官方文档：<https://developer.fnnas.com/docs/guide/>
- 范式来源：<https://github.com/shuangji66/buildbot>