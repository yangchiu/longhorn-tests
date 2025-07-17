longhornctl_check(){
  curl -L https://github.com/longhorn/cli/releases/download/v1.8.1/longhornctl-linux-amd64 -o longhornctl
  chmod +x longhornctl

  count=0
  max_retries=60

  while ! ./longhornctl install preflight; do
    count=$((count + 1))
    if [ "$count" -ge "$max_retries" ]; then
        exit 1
    fi
    sleep 10
  done

  count=0

  while ! ./longhornctl check preflight; do
    count=$((count + 1))
    if [ "$count" -ge "$max_retries" ]; then
        exit 1
    fi
    sleep 10
  done
}
