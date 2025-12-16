#!/usr/bin/env bun
/**
 * 获取实际使用的模型名称
 * 使用三级回退策略：
 * 1. 从 transcript JSONL 的最后一条 assistant 消息获取
 * 2. 从 claude-code-router 配置文件获取
 * 3. 从 Claude Code JSON 获取
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

interface StatusJSON {
  transcript_path?: string;
  model?: {
    id?: string;
    display_name?: string;
  };
  workspace?: {
    current_dir?: string;
  };
}

interface AssistantMessage {
  type: string;
  message?: {
    model?: string;
    usage?: {
      input_tokens?: number;
      output_tokens?: number;
    };
  };
}

interface RouterConfig {
  Router?: {
    default?: string;
    [key: string]: string | undefined;
  };
}

/**
 * 从 transcript JSONL 获取最后一条 assistant 消息的模型
 */
function getModelFromTranscript(transcriptPath: string): string | null {
  try {
    if (!existsSync(transcriptPath)) {
      return null;
    }

    const content = readFileSync(transcriptPath, 'utf-8');
    const lines = content.trim().split('\n').filter(line => line.trim());

    for (let i = lines.length - 1; i >= 0; i--) {
      try {
        const message: AssistantMessage = JSON.parse(lines[i] ?? '');
        if (message.type === 'assistant' && message.message?.model) {
          return message.message.model;
        }
      } catch {
        continue;
      }
    }
  } catch {
    return null;
  }

  return null;
}

/**
 * 从 claude-code-router 配置文件获取默认模型
 */
function getModelFromRouterConfig(): string | null {
  try {
    const globalConfigPath = join(homedir(), '.claude-code-router', 'config.json');
    if (existsSync(globalConfigPath)) {
      const content = readFileSync(globalConfigPath, 'utf-8');
      const config: RouterConfig = JSON.parse(content);
      if (config.Router?.default) {
        const [, defaultModel] = config.Router.default.split(',');
        if (defaultModel) {
          return defaultModel.trim();
        }
      }
    }
  } catch {
    return null;
  }

  return null;
}

async function main() {
  try {
    const input = await Bun.stdin.text();
    const data: StatusJSON = JSON.parse(input);

    let model: string | null = null;

    if (data.transcript_path) {
      model = getModelFromTranscript(data.transcript_path);
    }

    if (!model) {
      model = getModelFromRouterConfig();
    }

    if (!model) {
      model = data.model?.id ?? data.model?.display_name ?? null;
    }

    if (model) {
      console.log(model);
    }
  } catch (error) {
    process.exit(1);
  }
}

main();
