MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
sudo yum install -y cryptsetup
cat << EOF >> /etc/eks/bootstrap.sh
sudo yum install -y cryptsetup
EOF

--==MYBOUNDARY==--