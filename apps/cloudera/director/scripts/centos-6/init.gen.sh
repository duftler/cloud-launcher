
declare -r THRESHOLD="1.1"

function ratio_over_threshold() {
  local numer="${1}"
  local denom="${2}"
  local threshold="${3:-${THRESHOLD}}"

  if `which python > /dev/null 2>&1`; then
    python -c "print(1 if (1. * ${numer} / ${denom} > ${threshold}) else 0)"
  elif `which bc > /dev/null 2>&1`; then
    echo "${numer} / ${denom} > ${threshold}" | bc -l
  else
    echo "Neither python nor bc were found; calculation infeasible." >&2
    exit 1
  fi
}

function main() {
  local dev_sda="$(fdisk -s /dev/sda)"
  local dev_sda1="$(fdisk -s /dev/sda1)"

  if [ $(ratio_over_threshold "${dev_sda}" "${dev_sda1}") -eq 1 ]; then
    cat <<EOF | fdisk -c -u /dev/sda
d
n
p
1


w
EOF
    reboot
  else
    local dev_sda1_df="$(df -B 1K / | grep ' /$' | awk '{ print $2 }')"
    if [ $(ratio_over_threshold "${dev_sda}" "${dev_sda1_df}") -eq 1 ]; then
      resize2fs /dev/sda1
    fi
  fi
}

if [[ "$(basename $0)" != "fdisk_test.sh" ]]; then
  main
fi

function download_file() {
  local remote_url="$1"
  local local_path="$2"
  if [ -e "${local_path}" ]; then
    return
  fi

  if `which curl > /dev/null 2>&1`; then
    curl "${remote_url}" -o "${local_path}"
  elif `which wget > /dev/null 2>&1`; then
    wget "${remote_url}" -O "${local_path}"
  else
    echo "ERROR: neither curl nor wget are available." >&2
    exit 1
  fi
}

download_file \
    "http://archive.cloudera.com/director/redhat/6/x86_64/director/cloudera-director.repo" \
    "/etc/yum.repos.d/cloudera-director.repo"

yum -q makecache

yum -q -y install oracle-j2sdk1.7

yum -q -y install cloudera-director-{client,server}
service cloudera-director-server start
