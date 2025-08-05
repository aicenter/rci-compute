## rci_compute.sh: start/stop SSH tunnel on Slurm compute node with configurable parameters

# Configuration markers for ~/.ssh/config
SSH_CFG="$HOME/.ssh/config"
START_MARKER="# START rci-compute"
END_MARKER="# END rci-compute"

# Default parameters
USER_DEFAULT="$USER"
PARTITION_DEFAULT="cpufast"
TIME_DEFAULT="04:00:00"
MEM_DEFAULT="32G"
CPUS_DEFAULT=8
JOB_NAME="VSCodeSSH"
IDENTITY_FILE="$HOME/.ssh/rci"
RCI_LOGIN_HOST="rci"

# Helper: extract port from ~/.ssh/config
get_config_port() {
  sed -n "/${START_MARKER}/,/${END_MARKER}/ { /Port[[:space:]]\+\([0-9]\+\)/{ s//\1/; p } }" "$SSH_CFG" | head -n1
}

# Helper: update ssh config block
update_ssh_config() {
  local port="$1"
  sed -i.bak "/${START_MARKER}/,/${END_MARKER}/d" "$SSH_CFG"
  cat >> "$SSH_CFG" << EOF
${START_MARKER}
Host rci-compute
  HostName localhost
  Port     ${port}
  User     ${USER}
  IdentityFile ${IDENTITY_FILE}
  ServerAliveInterval 60
  ForwardAgent yes
${END_MARKER}
EOF
}

# Function: start or resume tunnel
start_rci_compute_ssh() {
  # parse options
  # support short and long flags: -u|--user, -p|--partition, -t|--time, -m|--mem, -r|--cpus
  USER=""
  PARTITION=""
  TIME_LIMIT=""
  MEM=""
  CPUS=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--user)
        USER="$2"; shift 2;;
      -p|--partition)
        PARTITION="$2"; shift 2;;
      -t|--time)
        TIME_LIMIT="$2"; shift 2;;
      -m|--mem)
        MEM="$2"; shift 2;;
      -r|--cpus)
        CPUS="$2"; shift 2;;
      *) echo "Unknown arg: $1"; return 1;;
    esac
  done

  # use defaults if not set
  USER=${USER:-$USER_DEFAULT}
  PARTITION=${PARTITION:-$PARTITION_DEFAULT}
  TIME_LIMIT=${TIME_LIMIT:-$TIME_DEFAULT}
  MEM=${MEM:-$MEM_DEFAULT}
  CPUS=${CPUS:-$CPUS_DEFAULT}

  # Check for existing running job
  local jobid node port
  jobid=$(ssh ${RCI_LOGIN_HOST} "squeue -h -o '%A' -u ${USER} -n ${JOB_NAME} -t RUNNING")
  if [[ -n "$jobid" ]]; then
    echo "Found existing job $jobid, reusing tunnel..."
    port=$(get_config_port)
  else
    echo "No existing job, submitting new..."
    port=$(shuf -i20000-30000 -n1)
    update_ssh_config "$port"

    jobid=$(ssh ${RCI_LOGIN_HOST} \
      "sbatch --parsable \
         --job-name=${JOB_NAME} \
         -p ${PARTITION} \
         --nodes=1 --ntasks=1 \
         --cpus-per-task=${CPUS} \
         --time=${TIME_LIMIT} \
         --mem=${MEM} \
         ~/rci_start_sshd.sh ${port}")
    echo "Launched sbatch job $jobid"
  fi

  # Determine node
  echo -n "Waiting for node assignment... "
  node=""
  while [[ -z "$node" ]]; do
    sleep 1
    node=$(ssh ${RCI_LOGIN_HOST} "scontrol show job $jobid --oneline" | sed -n 's/.*NodeList=\([^ ]*\).*/\1/p')
  done
  echo "node=$node"

  # Poll for sshd readiness
  echo -n "Waiting for sshd on $node:$port... "
  until ssh -q -o ConnectTimeout=2 -J ${RCI_LOGIN_HOST} ${USER}@${node} -p $port true; do
    printf .; sleep 1
  done
  echo "ready"

  # Open local tunnel (foreground)
  echo "Opening tunnel: localhost:$port -> $node:$port"
  ssh -N -L ${port}:${node}:${port} ${RCI_LOGIN_HOST}
}

# Function: stop job and clean config
stop_rci_compute_ssh() {
  local jobid
  jobid=$(ssh ${RCI_LOGIN_HOST} "squeue -h -o '%A' -n ${JOB_NAME} -t RUNNING")
  if [[ -n "$jobid" ]]; then
    echo "Cancelling job $jobid..."
    ssh ${RCI_LOGIN_HOST} "scancel $jobid"
  else
    echo "No running ${JOB_NAME} job found."
  fi
  # remove ssh config block
  sed -i.bak "/${START_MARKER}/,/${END_MARKER}/d" "$SSH_CFG"
  echo "SSH config entry removed."
}

# Entrypoint: rci_compute start|stop [options]
rci_compute() {
  case "$1" in
    start) shift; start_rci_compute_ssh "$@";;
    stop)  stop_rci_compute_ssh;;
    *) echo "Usage: rci_compute start [-u|--user USER] [-p|--partition PART] [-t|--time TIME] [-m|--mem MEM] [-r|--cpus CPUS]"; return 1;;
  esac
}
