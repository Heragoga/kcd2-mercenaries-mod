"""Local client for Blender MCP's documented addon socket transport.

Pass --code path.py to execute a Blender script, or --command get_scene_info.
The upstream addon handles execution on Blender's main thread. No UI input.
"""
import argparse
import json
import pathlib
import socket


def call(command, params=None, timeout=600):
    with socket.create_connection(('127.0.0.1', 9876), timeout=10) as sock:
        sock.settimeout(timeout)
        sock.sendall(json.dumps({'type': command, 'params': params or {}}).encode())
        data = bytearray()
        while True:
            block = sock.recv(65536)
            if not block:
                raise RuntimeError('Blender MCP disconnected before replying')
            data.extend(block)
            try:
                result = json.loads(data)
                break
            except (ValueError, UnicodeDecodeError):
                continue
    if result.get('status') != 'success':
        raise RuntimeError(result)
    return result


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--code', type=pathlib.Path)
    ap.add_argument('--command', default='get_scene_info')
    args = ap.parse_args()
    result = call('execute_code', {'code': args.code.read_text(encoding='utf-8')}) if args.code else call(args.command)
    print(json.dumps(result, ensure_ascii=True, indent=2))
