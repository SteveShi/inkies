# inkies Agent 规范

## Quick Reference
- 项目类型：macOS SwiftUI 应用（Swift 6.0+）
- 工程来源：`xcodegen` 生成，配置文件为 `project.yml`
- 生成工程：`sh scripts/generate_project.sh`
- 构建校验（必须）：`xcodebuild -project inkies.xcodeproj -scheme inkies -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
- 本地化资源：`inkies/Resources/Localizable.xcstrings`
- 关键约束：禁止硬编码可见文案；禁止 legacy fallback；优先复用现有 API

## Workflow Rules
- 不修改已验证可用的发布流水线关键逻辑：
  - `MDWriter/.github/workflows/release.yml` 中 `Extract Version`
  - `MDWriter/.github/workflows/release.yml` 中 `Extract Release Notes`
- Sparkle 2.x 发布签名流程需保持以下关键步骤：
  - 使用 `tr -dc A-Za-z0-9+/=` 清洗私钥
  - 设置 `DYLD_FRAMEWORK_PATH` 指向 Sparkle tools 目录
  - 使用 `echo "$KEY" | generate_appcast --ed-key-file -` 通过 stdin 签名
- 修改代码后必须执行一次可复现构建校验，确保无编译错误再交付。
- 任务结束前清理临时生成的 `*.log` / `*.txt` 文件。
- 不无必要新增实体（类型、层级、抽象）；优先最小改动。
- 优先使用仓库内现有接口与服务 API，不重复造轮子。

## 架构与目录约定
```text
project.yml                    # xcodegen 单一配置源
scripts/
  generate_project.sh          # 生成 Xcode 工程
inkies/
  inkiesApp.swift              # 应用入口
  ContentView.swift            # 主界面容器
  Models/                      # 领域模型（主题、导出、Issue 等）
  Services/                    # 业务服务（Ink 编译、高亮等）
  Views/
    Editor/                    # 编辑器与行号
    Preview/                   # 预览 WebView
  Utilities/                   # 辅助能力（HTML 生成、更新器、扩展）
  Resources/
    Localizable.xcstrings      # 唯一文案资源源
    Compiler/                  # inklecate 与运行时依赖
    Scripts/                   # ink.js 等脚本资源
```

## Coding Conventions
### Swift
- Swift 版本必须为 `6.0` 或更高。
- 新增功能按职责放入 `Models / Services / Views / Utilities`，保持目录语义清晰。
- 仅在必要时增加新类型；避免“为抽象而抽象”。
- 使用 `// MARK: -` 组织文件结构，命名遵循 Apple 风格。
- 不允许硬编码用户可见字符串，统一走 `Localizable.xcstrings`。
- Bundle Identifier 规范：`com.steveshi.appname`（新增 target/模块时遵守）。

### Localization
- 所有新增或修改的可见文案都必须进入 `Localizable.xcstrings`。
- 保持中英文键值一致，避免某一语言缺失。
- 不引入本地化兜底分支（no legacy fallback）。

### Release & Changelog
- 更新版本号时，必须同步更新 `CHANGELOG.md` 的英文与中文两部分。
- 格式要求：
  - 英文在上
  - 分隔线 `---`
  - 中文在下
- 文案样式需兼容 Sparkle 2.x 最新稳定版自动展示双语发布说明。

## 变更验收清单
- 已按需执行 `xcodegen`（当 `project.yml` 或工程结构变更时）。
- 已完成 Debug 构建且无错误。
- 已确认无硬编码可见字符串。
- 已确认无多余临时日志/文本文件残留。
- 若涉及发布：已检查 Sparkle 签名流程关键步骤与 changelog 双语格式。
