# 飞牛 fpk 安装包构建与发布

本仓库沿用 [shuangji66/buildbot](https://github.com/shuangji66/buildbot) 的方法，把 GitHub 上游开源应用打成飞牛 fnOS 的 `.fpk` 安装包，并自动发布到应用仓库。

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
│   └── AniRSS.yaml                        CI：下载 jar → 打 fpk → 发到 FnDepot
└── fnpack/
    ├── fnpack-1.2.1-linux-amd64           官方 fnpack CLI（amd64 runner 用）
    ├── fnpack-1.2.1-linux-arm64           官方 fnpack CLI（arm64 runner 用）
    └── AniRSS/                            AniRSS 的 fpk 打包模板（按 fnOS 规范）
        ├── manifest                       INI 风格元数据
        ├── ICON.PNG / ICON_256.PNG        桌面图标
        ├── config/{privilege,resource}    权限与资源声明
        ├── cmd/{main, install_*, ...}    9 个生命周期 bash 脚本
        ├── wizard/{install,uninstall,config}  用户表单 JSON
        └── app/
            ├── ui/{config, images/}       桌面入口与图标
            └── app_tmp/                   CI 把 ani-rss.jar 放这里
```

## AniRSS 构建

### 触发 CI

1. GitHub → Actions → `Build AniRSS and Release` → `Run workflow`
2. 填 4 个入参：
   - `version`：上游 release tag（不带 `v` 前缀），例 `3.1.74`
   - `manifest_version`：manifest 内的版本号（带 `-N` 重发布后缀），例 `3.1.74-1`
   - `changelog`：本次更新说明
   - `publish`：是否自动发到 `shupian35/FnDepot` Release + 更新 `fnpack.json`（默认 true）
3. CI 流程：
   - 从 `wushuo894/ani-rss` GitHub Releases 拉 `ani-rss.jar`
   - 把 jar 拷到 `fnpack/AniRSS/app/app_tmp/`
   - `sed` 替换 `manifest` 中的 `${VERSION}` / `${CHANGELOG}`
   - 调用 `fnpack build AniRSS` 产出 `AniRSS.fpk`
   - 重命名为 `AniRSS-<manifest_version>-all.fpk` 并上传为 artifact
   - （若 publish=true）发到 `shupian35/FnDepot` 当日 YYYY.M.D 聚合 Release 并自动更新 `fnpack.json`

### 本地构建

依赖：
- Windows 版 fnpack：<https://static2.fnnas.com/fnpack/fnpack-1.2.3-windows-amd64>（Windows 跑通要用这个）
- 或在 Linux runner 上用仓库自带的 `fnpack-1.2.1-linux-amd64`
- 联网

```powershell
# PowerShell 5.1+，Windows 上跑通过的脚本

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSCommandPath

# 1) 准备 staging
$buildDir = Join-Path $repoRoot "work\fpk-build\AniRSS"
if (Test-Path $buildDir) { Remove-Item -Recurse -Force $buildDir }
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $repoRoot "fnpack\AniROSS\*") $buildDir -ErrorAction SilentlyContinue
Copy-Item -Recurse -Force (Join-Path $repoRoot "fnpack\AniRSS\*") $buildDir

$appTmp = Join-Path $buildDir "app\app_tmp"
Remove-Item (Join-Path $appTmp ".keep") -ErrorAction SilentlyContinue
Invoke-WebRequest `
    -Uri "https://github.com/wushuo894/ani-rss/releases/download/v3.1.74/ani-rss.jar" `
    -OutFile (Join-Path $appTmp "ani-rss.jar") `
    -UseBasicParsing

# 2) sed 替换 manifest 占位符（必须无 BOM）
$manifest = Join-Path $buildDir "manifest"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$content  = [System.IO.File]::ReadAllText($manifest)
$content  = $content.Replace('${VERSION}',   '3.1.74-1')
$content  = $content.Replace('${CHANGELOG}', '"首次发布 (基于上游 v3.1.74)"')
[System.IO.File]::WriteAllText($manifest, $content, $utf8NoBom)

# 3) 调 fnpack
$fnpack = "C:\Users\shupian\Documents\Codex\2026-07-19\f-x-2\work\fnpack.exe"  # 或仓库 fnpack-1.2.1-linux-amd64
& $fnpack build --directory $buildDir

# 4) 重命名
Move-Item -Force `
    (Join-Path $buildDir "AniRSS.fpk") `
    (Join-Path $repoRoot "AniRSS-3.1.74-1-all.fpk")
```

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