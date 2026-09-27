# 1.6.9 — RED · USE · Golden Signals dashboards, plus demo scenarios that make
# each dashboard light up by feeding real traffic to the bank.
#
# Dashboards (Terraform -> Grafana):
#   make apply GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
#   make destroy GRAFANA_URL=...
#
# Scenarios (kubectl -> the bank cluster; run where kubectl reaches bankobs):
#   make scenario-red      # traffic + intentional 5xx errors        (RED / Golden)
#   make scenario-use      # saturate CPU / threads / DB pool         (USE)
#   make scenario-golden   # all four Golden Signals at once
#   make scenario-watch SCEN=red     # tail the generated traffic
#   make scenario-stop               # stop & remove all scenarios
# Override anything: TARGET=account-service PORT=8001 DURATION=300 CONCURRENCY=40 ERROR_PCT=25
#
GRAFANA_URL  ?= http://localhost:13000
GRAFANA_AUTH ?= admin:admin
TF = terraform -chdir=terraform

# scenario defaults
NS         ?= bankobs
TARGET     ?= account-service
PORT       ?= 8001
DURATION   ?= 300
LOAD_IMAGE ?= curlimages/curl:8.11.0

.DEFAULT_GOAL := apply
.PHONY: init apply plan destroy fmt \
        scenario-red scenario-use scenario-golden _scenario scenario-watch scenario-stop

# ---- dashboards (Terraform) ------------------------------------------------
init: ## download the Grafana provider, prepare the working dir
	$(TF) init -input=false

apply: init ## create the RED, USE and Golden-Signals dashboards
	$(TF) apply -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

plan: init ## preview the changes
	$(TF) plan -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

destroy: ## remove the three dashboards this created
	$(TF) destroy -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

fmt: ## format the terraform files
	$(TF) fmt

# ---- demo scenarios (kubectl load Jobs) ------------------------------------
scenario-red:    SCEN = red
scenario-red:    CONCURRENCY = 20
scenario-red:    ERROR_PCT = 25
scenario-red:    _scenario ## RED/Golden: steady traffic with intentional 5xx errors

scenario-use:    SCEN = use
scenario-use:    CONCURRENCY = 120
scenario-use:    ERROR_PCT = 0
scenario-use:    _scenario ## USE: high concurrency to saturate CPU, threads and the DB pool

scenario-golden: SCEN = golden
scenario-golden: CONCURRENCY = 60
scenario-golden: ERROR_PCT = 12
scenario-golden: _scenario ## Golden Signals: drive latency, traffic, errors and saturation together

_scenario:
	@command -v kubectl >/dev/null || { echo "kubectl not found — run scenarios where kubectl reaches the bank cluster"; exit 1; }
	kubectl -n $(NS) delete job load-$(SCEN) --ignore-not-found >/dev/null 2>&1 || true
	kubectl -n $(NS) create configmap load-$(SCEN) --from-file=run.sh=scenarios/$(SCEN).sh --dry-run=client -o yaml | kubectl -n $(NS) apply -f - >/dev/null
	sed -e 's/__SCEN__/$(SCEN)/g' -e 's/__NS__/$(NS)/g' -e 's|__IMAGE__|$(LOAD_IMAGE)|g' \
	    -e 's/__TARGET__/$(TARGET)/g' -e 's/__PORT__/$(PORT)/g' -e 's/__DURATION__/$(DURATION)/g' \
	    -e 's/__CONCURRENCY__/$(CONCURRENCY)/g' -e 's/__ERROR_PCT__/$(ERROR_PCT)/g' \
	    scenarios/loadjob.yaml | kubectl apply -f -
	@echo ""
	@echo "started load-$(SCEN)  ->  $(TARGET):$(PORT)  dur=$(DURATION)s conc=$(CONCURRENCY) err=$(ERROR_PCT)%"
	@echo "  watch traffic : make scenario-watch SCEN=$(SCEN)"
	@echo "  stop / clean  : make scenario-stop"

scenario-watch: ## tail a running scenario's traffic (SCEN=red|use|golden)
	kubectl -n $(NS) logs -f job/load-$(SCEN)

scenario-stop: ## stop and remove every scenario load Job
	-kubectl -n $(NS) delete job -l app=bankobs-load --ignore-not-found
	-kubectl -n $(NS) delete configmap load-red load-use load-golden --ignore-not-found
