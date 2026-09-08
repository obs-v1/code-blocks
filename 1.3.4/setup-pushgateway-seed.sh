#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-monitoring}"
RELEASE="${RELEASE:-prometheus}"
PROM_NODEPORT="${PROM_NODEPORT:-30990}"          # kind maps this -> host 9090
PG_NODEPORT="${PG_NODEPORT:-31300}"              # kind maps this -> host 13000
PG_SVC="${RELEASE}-prometheus-pushgateway"
VALUES="${VALUES:-/home/ec2-user/prometheus-values.yaml}"
JOB_IMAGE="${JOB_IMAGE:-curlimages/curl:8.10.1}"

log(){ printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

detect_ip(){
  local ip tok
  tok=$(curl -s -m 2 -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
  ip=$(curl -s -m 2 -H "X-aws-ec2-metadata-token: ${tok}" \
        http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)
  [ -z "${ip}" ] && ip=$(curl -s -m 3 https://checkip.amazonaws.com 2>/dev/null | tr -d '\n' || true)
  echo "${ip:-<node-ip>}"
}

clean_jobs(){
  log "Removing demo jobs and cronjob"
  kubectl delete jobs,cronjobs -n "${NS}" -l demo=pushgateway --ignore-not-found >/dev/null 2>&1 || true
  echo "demo workloads removed"
}


# Seed the batch-job fleet ----------------------------------------------------
log "Seeding batch-job fleet"
PG="http://${PG_SVC}.${NS}.svc:9091"
names="db-backup-orders db-backup-users db-backup-payments db-backup-inventory db-backup-analytics \
report-daily report-weekly report-monthly report-adhoc \
sync-crm sync-warehouse sync-billing sync-shipping \
cleanup-logs cleanup-temp cleanup-cache cleanup-sessions \
etl-ingest etl-transform etl-load etl-validate \
index-rebuild index-optimize mail-digest mail-alerts fraud-scan"
i=0
for j in ${names}; do
  i=$((i+1)); dur=$(((RANDOM%300)+3)); recs=$((RANDOM%500000)); ec=0; [ $((i%7)) -eq 0 ] && ec=1
  ts=$(( $(date +%s) - (RANDOM%3600) )); fam=$(echo "${j}" | cut -d- -f1)
  kubectl apply -f - >/dev/null <<JOB
apiVersion: batch/v1
kind: Job
metadata: { name: ${j}, namespace: ${NS}, labels: { demo: pushgateway } }
spec:
  ttlSecondsAfterFinished: 1800
  backoffLimit: 0
  template:
    metadata: { labels: { demo: pushgateway } }
    spec:
      restartPolicy: Never
      containers:
        - name: job
          image: ${JOB_IMAGE}
          command: ["/bin/sh","-c"]
          args:
            - |
              sleep 2
              printf 'batchjob_duration_seconds{family="${fam}"} %s\nbatchjob_records_processed_total{family="${fam}"} %s\nbatchjob_exit_code{family="${fam}"} %s\nbatchjob_last_success_timestamp_seconds{family="${fam}"} %s\n' ${dur} ${recs} ${ec} ${ts} | curl -s --data-binary @- ${PG}/metrics/job/${j}
JOB
done
echo "submitted ${i} batch jobs"

kubectl apply -f - >/dev/null <<CRON
apiVersion: batch/v1
kind: CronJob
metadata: { name: recurring-backup, namespace: ${NS}, labels: { demo: pushgateway } }
spec:
  schedule: "*/1 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 120
      template:
        metadata: { labels: { demo: pushgateway } }
        spec:
          restartPolicy: Never
          containers:
            - name: b
              image: ${JOB_IMAGE}
              command: ["/bin/sh","-c"]
              args:
                - |
                  printf 'batchjob_last_success_timestamp_seconds{family="recurring"} %s\nbatchjob_duration_seconds{family="recurring"} 12\nbatchjob_exit_code{family="recurring"} 0\n' "\$(date +%s)" | curl -s --data-binary @- ${PG}/metrics/job/recurring-backup
CRON
echo "recurring cronjob created (pushes every minute)"

log "Waiting for the batch to complete"
for _ in $(seq 1 24); do
  c=$(kubectl get jobs -n "${NS}" -l demo=pushgateway -o jsonpath='{range .items[*]}{.status.succeeded}{"\n"}{end}' 2>/dev/null | grep -c 1 || true)
  [ "${c:-0}" -ge 26 ] && break; sleep 5
done
groups=$(kubectl exec -n "${NS}" deploy/${RELEASE}-server -c prometheus-server -- \
         wget -qO- "${PG}/metrics" 2>/dev/null | grep -oE 'job="[^"]+"' | sort -u | wc -l || true)
echo "Pushgateway now holds ${groups} job groups"

# Summary ---------------------------------------------------------------------
IP=$(detect_ip)
log "Demo ready"
cat <<SUMMARY
  Prometheus UI   : http://${IP}:9090
  Pushgateway UI  : http://${IP}:13000
SUMMARY
