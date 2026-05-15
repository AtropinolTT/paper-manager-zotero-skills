# Claude Code 技能：论文总结 & Zotero 管理器

两个互补的 Claude Code 技能，覆盖从读论文到存文献库的完整学术工作流。可独立使用，也可串联。

## 技能

### paper-summarizer-v2 — 论文总结

将论文读入并总结为结构化 Markdown 笔记。

| | |
|---|---|
| **输入** | 网址、DOI、PMID、arXiv ID、PDF 文件 |
| **输出** | 结构化 Markdown（默认中文，可按需英文） |
| **模式** | 单篇总结、多篇总结、综合对比、文献调研 |
| **图表** | 尽力而为提取（本地 PDF）或文字描述 |
| **依赖** | `curl`, `python3` |

### zotero-manager — Zotero 管理器

通用 Zotero 文献库管理中枢。

| | |
|---|---|
| **导入** | DOI、PMID、arXiv、PDF、手动元数据、paper-summarizer .md 批量 |
| **笔记** | 增/改/删子笔记，支持 Markdown |
| **目录** | 关键词自动归类、创建/删除目录 |
| **标签** | 批量增删，按目录批量打标签 |
| **检索** | 按标题、作者、DOI、标签、目录、添加日期 |
| **PDF** | 查找 OA PDF、导入本地 PDF、检测缺失附件 |
| **维护** | 查重（DOI/标题）、孤儿检测、批量删除 |
| **依赖** | Node.js >= 18, `curl`, `python3` |

> zotero-manager 捆绑了修改版 [@xevos117/mcp-zotero](https://github.com/xevos117/mcp-zotero)，新增 `add_item_note` 工具。

## 快速开始

### 1. 安装

将两个目录复制到 Claude Code 技能目录：

```
~/.claude/skills/paper-summarizer-v2/
~/.claude/skills/zotero-manager/
```

或放入项目本地技能目录。

### 2. 配置 Zotero 管理器（仅需一次）

```bash
bash <skills-dir>/zotero-manager/scripts/setup.sh
```

安装 npm 依赖并提示输入 Zotero API 凭证。从 [zotero.org/settings/keys](https://www.zotero.org/settings/keys) 获取。

凭证写入 `.mcp.json`，不会出现在技能文件中。

### 3. 典型工作流

```
总结论文:
  → paper-summarizer-v2 阅读并生成笔记

把总结导入 Zotero:
  → zotero-manager 导入元数据 + 附加笔记 + 自动归类
```

## 兼容性

| 平台 | 支持程度 |
|------|---------|
| Claude Code (CLI) | 完整（MCP 工具 + curl 回退） |
| Claude.ai (Web) | 部分（Zotero 操作走 curl 回退） |
| Cowork | 完整 |

## 许可

MIT

## 致谢

- `paper-summarizer-v2` — 社区开发的论文阅读总结技能
- `zotero-manager` — 基于 [@xevos117/mcp-zotero](https://github.com/xevos117/mcp-zotero)，扩展了 `add_item_note` 功能
- 两个技能完全独立，但设计为互补配合
