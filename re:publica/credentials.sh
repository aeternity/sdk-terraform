#!/bin/bash
set -e

mkdir -p /srv/pillar

cat > /srv/pillar/top.sls <<'EOF'
base:
  '*':
    - aws
EOF

cat > /srv/pillar/aws.sls <<'EOF'
aws:
  id: ${access_key}
  key: ${secret_access_key}
EOF
