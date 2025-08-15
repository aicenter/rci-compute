#!/usr/bin/env bash
#
# rci_start_sshd.sh  <port>
#
# Starts sshd on the compute node in an sbatch job,
# logs everything to ~/.sshd_user/logs/sshd-<JOBID>.log, then sleeps
# for the duration of the allocation so Slurm doesn't kill it.

port="$1"
config="$HOME/.sshd_user/sshd_config"

# Create logs directory if it doesn't exist
mkdir -p "$HOME/.sshd_user/logs"

# Redirect *all* stdout+stderr into the per-job log:
exec &> "$HOME/.sshd_user/logs/sshd-${SLURM_JOB_ID}.log"

echo "=== Starting sshd on $(hostname -s):${port} ==="
echo "Using config: $config"

# Launch sshd
nohup /usr/sbin/sshd -D -f "$config" \
     -o ListenAddress=$(hostname -s) \
     -o Port="$port" &

echo "sshd PID=$!"

# Now sleep for a week
sleep 604800

