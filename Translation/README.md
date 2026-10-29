# Translation Module

从 [Harbor `feature/epub-opds`](https://github.com/zongai/Harbor/tree/feature/epub-opds) 移植的翻译接口，用于**自动翻译非目标语言**内容。

## 能力

| 引擎 | 是否需要 Key | 说明 |
|------|-------------|------|
| Google 翻译 | 否 | 默认首选 |
| Azure/Bing | 否 | 网页接口 |
| Yandex | 否 | 网页接口 |
| Lingva | 否 | 开源前端 |
| MyMemory | 否 | 免费配额 |
| Microsoft Translator | 是 | 官方 API |
| DeepL | 是 | 支持 Free (`:fx`) / Pro |
| AI 翻译 | 是 | OpenAI / Gemini / Anthropic 兼容 |

## 快速使用

```swift
// 目标语言：简体中文（默认）
AutoTranslator.shared.targetLanguage = .zhHans

// 非目标语言 → 自动翻译；已是目标语言则原样返回
let out = await AutoTranslator.shared.translateIfNeeded("Hello, world!")
// → "你好，世界！"

// 强制翻译
let forced = try await AutoTranslator.shared.translate("Bonjour")

// 可选：配置 Key / 引擎链
AutoTranslator.shared.engineChain = [.google, .azure, .deepl, .ai]
AutoTranslator.shared.deepLAPIKey = "your-key:fx"
```

## 文件

- `Types.swift` — `AppLanguage` / `TranslationEngine` / `AIProvider`
- `TranslationServices.swift` — 各引擎实现（DeepL、Google、AI…）与缓存、润色
- `TranslationCoordinator.swift` — 引擎链、冷却与 failover
- `AutoTranslator.swift` — **自动翻译非目标语言** 入口

## 集成说明

本模块为纯 Swift 源文件，可直接加入 Xcode / Bazel 目标。  
与 Telegram 内置翻译可并存：对消息气泡等场景调用 `translateIfNeeded` 即可。
