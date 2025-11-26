- Your context window will be automatically compacted as it approaches its limit. Never stop tasks early due to token budget concerns. Always complete tasks fully, even if the end of your budget is approaching
- Only create an abstraction if it's actually needed
- Prefer clear function/variable names over inline comments
- Avoid helper functions when a simple inline expression would suffice
- Use `npx knip` to remove unused code if making large changes
- Don't use emojis

## Tools

### context7

Always use context7 when I need code generation, setup or configuration steps, or library/API documentation. This means you should automatically use the Context7 MCP tools to resolve library id and get library docs without me having to explicitly ask.

### chrome-devtools

Always use chrome-devtools MCP when I need any of the following frontend tasks:

- Verifying frontend functionality or debugging UI behavior
- Taking screenshots (IMPORTANT: Always target specific elements only, NEVER capture full-page screenshots as they consume excessive tokens)
- Viewing browser console logs or errors
- Analyzing page performance and load times
- Monitoring network traffic and API requests
- Inspecting DOM structure or element properties

You must first verify that the current browser page matches the intended target page. Only proceed with tool operations after confirming the correct page context.

The chrome-devtools MCP provides direct browser automation and debugging capabilities for efficient frontend development workflow

### ast-grep

You run in an environment where `ast-grep` is available; whenever a search requires syntax-aware or structural matching, default to `ast-grep --lang ts -p '<pattern>'` (or set `--lang` appropriately) and avoid falling back to text-only tools like `rg` or `grep` unless I explicitly request a plain-text search.

## Vue

编写简洁明了，可读性高的 Vue 3 单文件组件代码。编码要求如下：

- 使用 Vue 3 的 Composition API 最佳实践；
- 使用 TypeScript；
- 样式使用 CSS 预处理器 Less.js
- 在 Template 当中类名应当符合直觉且使用 BEM 规范 (e.g., block__element--modifier)

## 其他注意事项：

- 调试打印始终使用 console.debug
- 在项目的 `node_modules/` 中定位并打开目标内部库（如 `@tencent/*`）的源码进行阅读；查找顺序：进入对应包目录后先查看 `package.json` 的 `exports`/`main`/`types` 字段→再在 `src/`、`lib/` 或 `dist/` 中寻找源码；若只有构建产物，利用 `.map` 与 `.d.ts` 辅助理解

