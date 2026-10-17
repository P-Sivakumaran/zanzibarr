#!/usr/bin/env python3
"""Bridge stdio MCP clients to the running Zanzibarr loopback endpoint.

Python 3.10+. Set ZANZIBARR_MCP_TOKEN in the client's environment, never args.
Optional ZANZIBARR_MCP_PORT defaults to 18472. No AI account tokens are used.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    token = os.environ.get('ZANZIBARR_MCP_TOKEN', '')
    port = os.environ.get('ZANZIBARR_MCP_PORT', '18472')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,512}', token) or not port.isdecimal() or not 1024 <= int(port) <= 65535:
        print('Set the Zanzibarr MCP access token and valid local port in the client environment.', file=sys.stderr)
        return 2
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    while True:
        line = sys.stdin.buffer.readline(65537)
        if not line:
            return 0
        if len(line) > 65536:
            print('MCP request exceeded the size limit.', file=sys.stderr)
            return 2
        request_id = None
        has_id = False
        try:
            message = json.loads(line)
            if not isinstance(message, dict):
                raise ValueError('Invalid request')
            has_id = 'id' in message
            request_id = message.get('id')
            request = urllib.request.Request(
                'http://127.0.0.1:' + port + '/mcp', data=line, method='POST',
                headers={'Authorization': 'Bearer ' + token,
                         'Content-Type': 'application/json',
                         'Accept': 'application/json, text/event-stream',
                         'MCP-Protocol-Version': '2025-11-25'})
            with opener.open(request, timeout=35) as response:
                body = response.read(2 * 1024 * 1024 + 1)
                if len(body) > 2 * 1024 * 1024:
                    raise ValueError('Oversized response')
                if not has_id:
                    continue
                result = json.loads(body)
                if not isinstance(result, dict) or result.get('id') != request_id:
                    raise ValueError('Invalid response')
            print(json.dumps(result, separators=(',', ':')), flush=True)
        except (ValueError, OSError, urllib.error.URLError):
            if has_id:
                print(json.dumps({'jsonrpc': '2.0', 'id': request_id, 'error': {
                    'code': -32000, 'message': 'Cannot reach Zanzibarr MCP. Open the app and check local MCP settings and token.'}}), flush=True)


if __name__ == '__main__':
    sys.exit(main())
