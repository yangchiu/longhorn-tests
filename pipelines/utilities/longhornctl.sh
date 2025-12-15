longhornctl_check(){
  curl -L https://github.com/longhorn/cli/releases/download/untagged-146fd4ea8ae53e56d2bf/longhornctl-linux-amd64 -o longhornctl
  chmod +x longhornctl
  ./longhornctl install preflight --enable-spdk
  ./longhornctl check preflight --enable-spdk
}
