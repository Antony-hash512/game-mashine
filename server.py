#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 8200

class GodotHTML5HTTPServer(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Adding headers required for Godot 4 HTML5 exports (SharedArrayBuffer support)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        super().end_headers()

def main():
    # If a directory argument is provided, change to that directory
    if len(sys.argv) > 1:
        os.chdir(sys.argv[1])
    
    print(f"Starting Godot 4 Web Server on http://localhost:{PORT}")
    print(f"Serving directory: {os.getcwd()}")
    print("Press Ctrl+C to stop.")
    
    # Allow address reuse
    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", PORT), GodotHTML5HTTPServer) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server.")
        sys.exit(0)

if __name__ == "__main__":
    main()
