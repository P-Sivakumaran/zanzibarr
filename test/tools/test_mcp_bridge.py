import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import unittest

BRIDGE = Path(__file__).resolve().parents[2] / 'tools/zanzibarr_mcp_bridge.py'


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.requests = []
        requests = self.requests

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                requests.append((self.path, self.headers.get('Authorization')))
                data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                if 'id' not in data:
                    self.send_response(202)
                    self.end_headers()
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'jsonrpc': '2.0', 'id': data['id'], 'result': {'ok': True}}).encode())

            def log_message(self, *args):
                pass

        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def run_bridge(self, messages, **extra_env):
        env = dict(os.environ, ZANZIBARR_MCP_TOKEN='TESTPASS123',
                   ZANZIBARR_MCP_PORT=str(self.server.server_port))
        env.update(extra_env)
        return subprocess.run([sys.executable, str(BRIDGE)], input=messages,
                              text=True, capture_output=True, env=env, timeout=10)

    def test_request_round_trip_and_notification_have_clean_stdio(self):
        result = self.run_bridge('{"jsonrpc":"2.0","id":1,"method":"initialize"}\n'
                                 '{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout), {'jsonrpc': '2.0', 'id': 1, 'result': {'ok': True}})
        self.assertEqual(result.stderr, '')
        self.assertEqual(self.requests, [('/mcp', 'Bearer TESTPASS123'), ('/mcp', 'Bearer TESTPASS123')])
        self.assertNotIn('TESTPASS123', result.stdout)

    def test_missing_token_fails_without_network_or_token_output(self):
        result = self.run_bridge('{}\n', ZANZIBARR_MCP_TOKEN='')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.requests, [])
        self.assertEqual(result.stdout, '')

    def test_oversized_requests_are_rejected_before_network(self):
        result = self.run_bridge('x' * 65537)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.requests, [])
        self.assertNotIn('TESTPASS123', result.stderr)


if __name__ == '__main__':
    unittest.main()
