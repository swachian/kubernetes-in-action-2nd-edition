#!/usr/bin/env bash

set -e

PROXY_PORT=7897

echo "===> Detecting Docker network gateway..."

# 获取 kind network 的网关 IP（宿主机）
GATEWAY_IP=$(docker network inspect kind \
  -f '{{(index .IPAM.Config 0).Gateway}}')

GATEWAY_IP=172.20.0.1

if [ -z "$GATEWAY_IP" ]; then
  echo "❌ Failed to detect gateway IP"
  exit 1
fi

echo "✅ Gateway IP: $GATEWAY_IP"

PROXY="http://${GATEWAY_IP}:${PROXY_PORT}"

echo "===> Using proxy: $PROXY"

# 获取所有 kind 节点
NODES=$(kind get nodes)

for NODE in $NODES; do
  echo "===> Configuring node: $NODE"

  docker exec "$NODE" bash -c "mkdir -p /etc/systemd/system/containerd.service.d"

  docker exec "$NODE" bash -c "cat <<EOF > /etc/systemd/system/containerd.service.d/http-proxy.conf
[Service]
Environment=\"HTTP_PROXY=$PROXY\"
Environment=\"HTTPS_PROXY=$PROXY\"
EOF"

  docker exec "$NODE" bash -c "systemctl daemon-reexec"
  docker exec "$NODE" bash -c "systemctl restart containerd"

  echo "✅ $NODE configured"
done

echo "🎉 All nodes are now using proxy: $PROXY"