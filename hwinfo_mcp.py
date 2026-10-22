"""Local stdio MCP bridge. Reads only HWiNFO's published sensor mapping."""
import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent

def snapshot():
    with tempfile.TemporaryDirectory(prefix='hwinfo-mcp-') as temp_dir:
        output = pathlib.Path(temp_dir) / 'sensors.json'
        result = subprocess.run(
            ['powershell.exe', '-NoProfile', '-File', str(ROOT / 'read-hwinfo.ps1'), '-OutputPath', str(output)],
            capture_output=True, text=True, timeout=20,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return json.loads(output.read_text(encoding='utf-8-sig'))

def dispatch(req):
    method = req.get('method')
    if method == 'initialize':
        return {'protocolVersion': '2024-11-05', 'capabilities': {'tools': {}},
                'serverInfo': {'name': 'local-hwinfo-reader', 'version': '1.0.0'}}
    if method == 'tools/list':
        return {'tools': [{'name': 'hwinfo_snapshot',
                'description': 'Read all published HWiNFO sensors: current, min, max, average. No hardware writes.',
                'inputSchema': {'type': 'object', 'properties': {}, 'additionalProperties': False}}]}
    if method == 'tools/call':
        if req.get('params', {}).get('name') != 'hwinfo_snapshot':
            raise ValueError('Unknown tool')
        return {'content': [{'type': 'text', 'text': json.dumps(snapshot(), ensure_ascii=False)}]}
    if method == 'ping':
        return {}
    raise ValueError('Unsupported method')

if __name__ == '__main__':
    if '--snapshot' in sys.argv:
        print(json.dumps(snapshot(), ensure_ascii=False, indent=2))
    else:
        for line in sys.stdin:
            try:
                req = json.loads(line)
                if 'id' not in req:
                    continue
                try:
                    answer = {'jsonrpc': '2.0', 'id': req['id'], 'result': dispatch(req)}
                except Exception as exc:
                    answer = {'jsonrpc': '2.0', 'id': req['id'], 'error': {'code': -32603, 'message': str(exc)}}
                print(json.dumps(answer, ensure_ascii=False), flush=True)
            except json.JSONDecodeError:
                print('Invalid JSON input', file=sys.stderr, flush=True)
