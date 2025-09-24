#!/bin/bash

# Check if subnet is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <subnet>"
    exit 1
fi

SUBNET="$1"
TIMESTAMP=$(date +%F_%H%M%S)
REPORT_FILE="cluster_ip_report_${TIMESTAMP}.txt"

echo "[*] Writing report to $REPORT_FILE"
echo "[*] Scanning subnet $SUBNET for active hosts..."

# Example of IP scanning; replace this with your actual logic
# Here we simulate scanning and write directly to report
echo "[*] Building IP map for $SUBNET..." > "$REPORT_FILE"

for ip in $(seq 1 254); do
    CURRENT_IP="${SUBNET%.*}.$ip"
    # Check if pingable; adjust ping command if needed
    if ping -c 1 -W 1 "$CURRENT_IP" &> /dev/null; then
        echo "$CURRENT_IP     [IN USE]" >> "$REPORT_FILE"
    else
        echo "$CURRENT_IP     [FREE?]" >> "$REPORT_FILE"
    fi
done

# Print summary of free IPs
echo "------------------------------------" >> "$REPORT_FILE"
echo "[*] Summary of candidate FREE IPs:" >> "$REPORT_FILE"
grep "FREE?" "$REPORT_FILE" | awk '{print $1}' >> "$REPORT_FILE"

echo "[*] Report saved to $REPORT_FILE"

# Start HTTP server
PORT=8080
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo "[*] Download your report at: http://$IP_ADDRESS:$PORT/$REPORT_FILE"

python3 - <<EOF
import http.server
import socketserver

PORT = $PORT
REPORT = "$REPORT_FILE"

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.endswith(REPORT):
            self.send_response(200)
            self.send_header("Content-type", "application/octet-stream")
            self.send_header("Content-Disposition", f'attachment; filename="{REPORT}"')
            self.end_headers()
            with open(REPORT, "rb") as f:
                self.wfile.write(f.read())
        else:
            # show a simple page with clickable link
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(f'<html><body><h2>Click to download report:</h2><a href="{REPORT}">{REPORT}</a></body></html>'.encode('utf-8'))

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
EOF
