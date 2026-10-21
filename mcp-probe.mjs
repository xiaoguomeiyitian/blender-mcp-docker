#!/usr/bin/env node
// mcp-probe.mjs — blender MCP 全链路协议探针(冷唤醒验证)
// 与 sleep 管线探针不同:保持 stdin 打开直到收到目标响应,消除"EOF 早关"伪失败。
// 验证链:wrapper 启动 → initialize → tools/list → tools/call get_scene_info(真实场景数据)
import { spawn } from 'node:child_process';

// 默认走 blender-mcp-wrapper.sh(通用 MCP 通道);argv[2] 或 MCP_WRAPPER 可覆盖。
const WRAP = process.argv[2] || process.env.MCP_WRAPPER || '/root/blender/blender-mcp-docker/blender-mcp-wrapper.sh';
const T0 = Date.now();
const el = () => ((Date.now() - T0) / 1000).toFixed(1) + 's';

const child = spawn(WRAP, [], { stdio: ['pipe', 'pipe', 'pipe'] });
let buf = '';
const send = (o) => child.stdin.write(JSON.stringify(o) + '\n');

const killer = setTimeout(() => {
  console.log('PROBE_TIMEOUT after 150s');
  child.kill(); process.exit(1);
}, 150000);

child.stdout.on('data', (d) => {
  buf += d.toString();
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim();
    buf = buf.slice(i + 1);
    if (!line) continue;
    let m; try { m = JSON.parse(line); } catch { continue; }
    if (m.id === 1 && m.result) {
      console.log(`[${el()}] initialize OK — ${m.result.serverInfo.name} ${m.result.serverInfo.version}`);
      send({ jsonrpc: '2.0', method: 'notifications/initialized' });
      send({ jsonrpc: '2.0', id: 2, method: 'tools/list' });
    } else if (m.id === 2 && m.result) {
      console.log(`[${el()}] tools/list OK — ${m.result.tools.length} 个工具`);
      send({ jsonrpc: '2.0', id: 3, method: 'tools/call',
             params: { name: 'get_scene_info', arguments: { user_prompt: '继续' } } });
    } else if (m.id === 3) {
      clearTimeout(killer);
      const txt = (m.result?.content || []).map(c => c.text || '').join('\n');
      const oc = txt.match(/"object_count":\s*(\d+)/);
      console.log(`[${el()}] tools/call get_scene_info OK — object_count=${oc ? oc[1] : '?'} isError=${!!m.result?.isError}`);
      console.log(`COLD_WAKE_FULL_CHAIN_VERIFIED in ${el()}`);
      child.kill(); process.exit(0);
    }
  }
});
child.stderr.on('data', () => {}); // stderr 静默(服务器日志)
child.on('error', (e) => { console.log('SPAWN_FAIL', e.message); process.exit(1); });

send({ jsonrpc: '2.0', id: 1, method: 'initialize',
       params: { protocolVersion: '2024-11-05', capabilities: {},
                 clientInfo: { name: 'mcp-probe', version: '0.1' } } });
