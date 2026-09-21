#!/usr/bin/env python3
"""
Generate one Grafana dashboard per Grafana-13 transformation.

Each dashboard has a single panel that queries the bankobserve360 Prometheus
(datasource uid "prometheus") and applies exactly ONE transformation, so you
can see that transformation in isolation. Run:

    python3 build_dashboards.py

It writes dashboards/NN-<slug>.json and regenerates README.md.

Transformation IDs are taken verbatim from Grafana v13.2.2
(packages/grafana-data/src/transformations/transformers/ids.ts).
"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "dashboards")
os.makedirs(OUT, exist_ok=True)

DS = {"type": "prometheus", "uid": "prometheus"}

# ---- reusable bank queries -------------------------------------------------
# per-service request rate, as a time series (range)
def ts(expr, legend="{{service}}", refId="A", instant=False, fmt=None):
    t = {"refId": refId, "expr": expr, "datasource": DS, "legendFormat": legend}
    if instant: t["instant"] = True
    if fmt: t["format"] = fmt
    return t

RATE_BY_SVC   = "topk(6, sum by (service) (rate(http_server_requests_seconds_count[5m])))"
RATE_BY_SVC_ALL = "sum by (service) (rate(http_server_requests_seconds_count[5m]))"
RATE_BY_SVC_OUT = "sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))"
ERR_BY_SVC    = "sum by (service) (rate(http_server_requests_seconds_count{outcome!=\"SUCCESS\"}[5m]))"
BUCKETS       = "sum by (le) (rate(http_server_requests_seconds_bucket[5m]))"
LAT_BY_SVC    = "histogram_quantile(0.95, sum by (service, le) (rate(http_server_requests_seconds_bucket[5m])))"

# ---- the 34 transformations ------------------------------------------------
# Each spec: slug,title,id, panel, targets(list), options(dict),
#   what/demo/look = README prose.
SPECS = [
 dict(slug="reduce", title="Reduce", id="reduce", panel="table",
   targets=[ts(RATE_BY_SVC)],
   options={"reducers":["last","mean","max"],"mode":"reduceFields","includeTimeField":False},
   what="Collapses each time series down to a single number per calculation — turning a range of points into one summary value.",
   demo="Six per-service request-rate series go in; the transform outputs a table with one row per series and a column for each reducer (last, mean, max).",
   look="Instead of lines over time you get a compact table: Field | Last | Mean | Max."),

 dict(slug="calculate-field", title="Add field from calculation", id="calculateField", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"mode":"binary","binary":{"left":"Value","operator":"*","right":"100"},
            "alias":"Value ×100","replaceFields":False},
   what="Creates a NEW field by calculating across existing fields — a binary op (A/B, A-B), a row reduction (sum of fields), or a scalar op.",
   demo="The per-service rate table gains a computed column 'Value ×100' = Value × 100 (a scalar binary op).",
   look="A new numeric column appears beside Value, each cell 100× the original."),

 dict(slug="organize", title="Organize fields by name", id="organize", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"excludeByName":{"Time":True},"indexByName":{},
            "renameByName":{"service":"Service","Value":"Requests / sec"}},
   what="Rename, reorder, and hide columns from a single query — the everyday 'make this table presentable' transform.",
   demo="Hides the Time column and renames service→Service and Value→'Requests / sec'.",
   look="A tidy two-column table with human headers; the raw Time column is gone."),

 dict(slug="filter-fields-by-name", title="Filter fields by name", id="filterFieldsByName", panel="table",
   targets=[ts(RATE_BY_SVC_OUT, instant=True, fmt="table")],
   options={"include":{"pattern":"service|Value"}},
   what="Keeps or drops whole columns (fields) by name, regex, or dashboard variable.",
   demo="The raw table has service, outcome and Value columns; the regex 'service|Value' keeps only service and Value.",
   look="The outcome column disappears; only service and Value remain."),

 dict(slug="filter-by-value", title="Filter data by values", id="filterByValue", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"type":"include","match":"any",
            "filters":[{"fieldName":"Value","config":{"id":"greater","options":{"value":0.1}}}]},
   what="Keeps or drops individual ROWS based on a condition on a field's value.",
   demo="Keeps only rows where Value (req/s) is greater than 0.1 — the busier services.",
   look="Low-traffic services drop out; only rows above the 0.1 req/s threshold survive."),

 dict(slug="filter-by-refid", title="Filter data by query refId", id="filterByRefId", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, legend="total {{service}}", refId="A", instant=True, fmt="table"),
            ts(ERR_BY_SVC, legend="errors {{service}}", refId="B", instant=True, fmt="table")],
   options={"include":"A"},
   what="In a multi-query panel, hides the results of whole queries by their refId — without deleting the query.",
   demo="Two queries (A = total, B = errors) both run; the transform includes only refId A.",
   look="Query B's rows are hidden even though it still executes; only A is shown."),

 dict(slug="rename-by-regex", title="Rename by regex", id="renameByRegex", panel="table",
   targets=[ts(RATE_BY_SVC, legend="{{service}}")],
   options={"regex":"(.*)-service","renamePattern":"$1"},
   what="Renames field (column/series) names using a regex match and replacement pattern.",
   demo="Each series is named by its service (account-service, auth-service, …). The pattern (.*)-service → $1 strips the '-service' suffix.",
   look="Column/series names shorten: 'account-service' becomes 'account'."),

 dict(slug="sort-by", title="Sort by", id="sortBy", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"sort":[{"field":"Value","desc":True}]},
   what="Sorts the rows of each frame by a chosen field, ascending or descending.",
   demo="Sorts the per-service table by Value descending — busiest service first.",
   look="Rows reorder so the highest req/s is on top."),

 dict(slug="limit", title="Limit", id="limit", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"limitField":5},
   what="Caps the number of rows shown, for a focused view of the first N.",
   demo="Shows only the first 5 rows of the per-service table.",
   look="At most five services appear, however many the query returned."),

 dict(slug="labels-to-fields", title="Labels to fields", id="labelsToFields", panel="table",
   targets=[ts(RATE_BY_SVC_OUT, legend="", refId="A")],
   options={"mode":"columns","keepLabels":["service","outcome"]},
   what="Turns time-series labels (service, outcome, …) into their own table columns (or rows).",
   demo="A time series labelled by service and outcome becomes a table with explicit service and outcome columns plus the value.",
   look="Labels that were hidden inside the series legend become first-class columns."),

 dict(slug="series-to-rows", title="Series to rows", id="seriesToRows", panel="table",
   targets=[ts(RATE_BY_SVC)],
   options={},
   what="Merges multiple time-series results into one long table of Time | Metric | Value rows.",
   demo="Six per-service series are stacked into a single three-column table, one row per (time, series, value).",
   look="One tall table with a Metric column naming which series each value came from."),

 dict(slug="join-by-field", title="Join by field", id="joinByField", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, legend="", refId="A", instant=True, fmt="table"),
            ts(ERR_BY_SVC, legend="", refId="B", instant=True, fmt="table")],
   options={"byField":"service","mode":"outer"},
   what="Merges several results into one wide table by matching on a shared field (a SQL-style outer/inner join).",
   demo="Query A (total rate) and B (error rate) are joined on the service column into one row per service with both values.",
   look="One table: service | Value 1 (total) | Value 2 (errors) — the two queries side by side."),

 dict(slug="join-by-labels", title="Join by labels", id="joinByLabels", panel="table",
   targets=[ts(RATE_BY_SVC_OUT, legend="", refId="A")],
   options={"value":"outcome"},
   what="Joins multiple time series into one wide table using their shared labels as the join keys.",
   demo="Series labelled by service+outcome are pivoted so each outcome becomes a column, keyed by the remaining labels.",
   look="A wide table keyed by label with one column per outcome value."),

 dict(slug="merge", title="Merge series/tables", id="merge", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, legend="", refId="A", instant=True, fmt="table"),
            ts(ERR_BY_SVC, legend="", refId="B", instant=True, fmt="table")],
   options={},
   what="Combines the rows of multiple queries/tables into a single result, aligning shared columns.",
   demo="The total-rate table and the error-rate table are merged into one combined table.",
   look="Rows from both queries appear in one table, matching columns lined up."),

 dict(slug="concatenate", title="Concatenate fields", id="concatenate", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, legend="", refId="A", instant=True, fmt="table"),
            ts(ERR_BY_SVC, legend="", refId="B", instant=True, fmt="table")],
   options={"frameNameMode":"field","frameNameLabel":"frame"},
   what="Pulls every field from multiple frames into one frame, placing them side by side.",
   demo="All columns from the two queries are concatenated into a single wide frame.",
   look="One frame containing the fields of both queries together."),

 dict(slug="prepare-time-series", title="Prepare time series", id="prepareTimeSeries", panel="timeseries",
   targets=[ts(RATE_BY_SVC)],
   options={"format":"wide"},
   what="Converts time-series data between 'wide' (one column per series) and 'long' (tidy) formats so a visualization can read it.",
   demo="The per-service series are reshaped to the wide multi-frame format many panels expect.",
   look="The lines render normally; the transform fixes frame shape rather than changing the picture."),

 dict(slug="time-series-to-table", title="Time series to table", id="timeSeriesTable", panel="table",
   targets=[ts(RATE_BY_SVC)],
   options={},
   what="Converts time-series results into a table with a sparkline cell summarising each series' trend.",
   demo="Each per-service series becomes one table row with a mini trend (sparkline) cell.",
   look="A row per service with a tiny inline chart of its recent rate."),

 dict(slug="transpose", title="Transpose", id="transpose", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={},
   what="Pivots the table — rows become columns and columns become rows.",
   demo="The service/Value table is flipped so services become column headers.",
   look="What was a tall two-column table becomes a wide one-row-per-metric table."),

 dict(slug="group-by", title="Group by", id="groupBy", panel="table",
   targets=[ts(RATE_BY_SVC_OUT, instant=True, fmt="table")],
   options={"fields":{"outcome":{"aggregations":[],"operation":"groupby"},
                       "Value":{"aggregations":["sum","count"],"operation":"aggregate"}}},
   what="Groups rows by a field and applies calculations (sum, count, mean, …) to the others — like SQL GROUP BY.",
   demo="Groups the service/outcome/Value table by outcome and sums+counts the Value per outcome.",
   look="One row per outcome (SUCCESS, CLIENT_ERROR, …) with summed and counted request rate."),

 dict(slug="grouping-to-matrix", title="Grouping to matrix", id="groupingToMatrix", panel="table",
   targets=[ts(RATE_BY_SVC_OUT, instant=True, fmt="table")],
   options={"columnField":"outcome","rowField":"service","valueField":"Value"},
   what="Builds a matrix/pivot table from three fields: one becomes rows, one becomes columns, one fills the cells.",
   demo="service → rows, outcome → columns, Value → cells: a service×outcome matrix of request rates.",
   look="A grid with services down the side, outcomes across the top, rates in the cells."),

 dict(slug="group-to-nested-table", title="Group to nested tables", id="groupToNestedTable", panel="table",
   targets=[ts(RATE_BY_SVC_OUT, instant=True, fmt="table")],
   options={"fields":{"service":{"aggregations":[],"operation":"groupby"}}},
   what="Groups rows and tucks the members of each group into an expandable nested sub-table.",
   demo="Groups by service; each service row expands to reveal its per-outcome rows.",
   look="A collapsed table of services; click a row to expand its outcome breakdown."),

 dict(slug="partition-by-values", title="Partition by values", id="partitionByValues", panel="table",
   targets=[ts(RATE_BY_SVC_OUT, instant=True, fmt="table")],
   options={"fields":["outcome"],"keepFields":False,"naming":{"asLabels":False}},
   what="Splits one result into several frames, one per unique value of the chosen field.",
   demo="Partitions the table by outcome, producing a separate frame for SUCCESS, CLIENT_ERROR, etc.",
   look="Multiple frames/tables, each holding only the rows for one outcome."),

 dict(slug="rows-to-fields", title="Rows to fields", id="rowsToFields", panel="stat",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"mappings":[{"fieldName":"service","handlerKey":"field.name"},
                        {"fieldName":"Value","handlerKey":"field.value"}]},
   what="Turns each row into its own field — using one column for the field NAME and another for its VALUE (and even config).",
   demo="Each service row becomes a named field whose value is its request rate; a Stat panel then shows one big number per service.",
   look="Instead of a table, a row of stat tiles, one per service, labelled by service name."),

 dict(slug="config-from-query", title="Config from query results", id="configFromData", panel="gauge",
   targets=[ts("vector(1)", legend="", refId="A", instant=True, fmt="table"),
            ts(RATE_BY_SVC_ALL, legend="", refId="B", instant=True, fmt="table")],
   options={"configRefId":"A","mappings":[{"fieldName":"Value","handlerKey":"max"}]},
   what="Reads standard options (Max, Min, Unit, Thresholds) from one query and applies them to another query's fields.",
   demo="Query A returns a constant (1) used as the Max; query B's per-service rates are then gauged against that Max.",
   look="The gauges are scaled to the Max supplied by query A rather than an auto-range."),

 dict(slug="convert-field-type", title="Convert field type", id="convertFieldType", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"conversions":[{"targetField":"Value","destinationType":"string"}]},
   what="Changes a field's type — number, string, time, boolean, or enum — so downstream transforms/panels treat it correctly.",
   demo="Converts the numeric Value column to a string.",
   look="Value renders left-aligned as text rather than a right-aligned number."),

 dict(slug="extract-fields", title="Extract fields", id="extractFields", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"source":"service","format":"regex","regExp":"(?<team>.*)-service","keepTime":False,"replace":False},
   what="Parses a source field (JSON, key=value, or regex) and pulls out new fields from inside it.",
   demo="Applies regex (?<team>.*)-service to the service column, extracting a new 'team' field.",
   look="A new 'team' column appears with the service name minus its suffix."),

 dict(slug="format-string", title="Format string", id="formatString", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"stringField":"service","substringStart":0,"substringEnd":100,"outputFormat":"Upper Case"},
   what="Reformats a string field — upper/lower/title case, trim, or substring.",
   demo="Upper-cases the service column.",
   look="Service names render in ALL CAPS."),

 dict(slug="format-time", title="Format time", id="formatTime", panel="table",
   targets=[ts(RATE_BY_SVC)],
   options={"timeField":"Time","outputFormat":"YYYY-MM-DD HH:mm:ss","useTimezone":True},
   what="Formats a time field with a Moment.js pattern so timestamps read the way you want.",
   demo="Formats the Time column as 'YYYY-MM-DD HH:mm:ss'.",
   look="The Time column shows friendly, fully-formatted timestamps."),

 dict(slug="field-lookup", title="Lookup fields from resource", id="fieldLookup", panel="table",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"lookupField":"service","gazetteer":"public/gazetteer/countries.json"},
   what="Enriches a field by looking values up in a gazetteer (e.g. country/US-state → coordinates & names).",
   demo="Attempts to look up the service field against the built-in countries gazetteer. (Bank services aren't countries, so this mostly shows the mechanism / how a non-match behaves.)",
   look="Extra lookup columns are added where a value matches the gazetteer; a real use would query a field of country codes."),

 dict(slug="histogram", title="Histogram", id="histogram", panel="histogram",
   targets=[ts(RATE_BY_SVC_ALL)],
   options={"bucketSize":None,"bucketOffset":0,"combine":False},
   what="Buckets the input values and counts how many fall in each bucket — a distribution of the numbers themselves.",
   demo="Takes the per-service request rates and bins them into a histogram of 'how many services run at each rate'.",
   look="A bar chart of value buckets vs count, computed by Grafana from the series."),

 dict(slug="heatmap", title="Create heatmap", id="heatmap", panel="heatmap",
   targets=[ts(RATE_BY_SVC_ALL)],
   options={"xBuckets":{"mode":"count","value":""},"yBuckets":{"mode":"count","value":""}},
   what="Calculates a heatmap (x/y bucketed density) from ordinary series inside Grafana — distinct from Prometheus-side histogram buckets.",
   demo="Grafana buckets the per-service rate series over time into a calculated heatmap.",
   look="A time × value density grid coloured by count."),

 dict(slug="regression", title="Trendline (regression)", id="regression", panel="timeseries",
   targets=[ts("sum(rate(http_server_requests_seconds_count[5m]))", legend="fleet req/s", refId="A")],
   options={"modelType":"linear","predictionCount":100},
   what="Fits a linear or polynomial regression to the data and draws the predicted trendline alongside it.",
   demo="Adds a straight-line linear trend over the noisy fleet request-rate series.",
   look="The jagged rate line gains a smooth straight trendline showing its direction."),

 dict(slug="smoothing", title="Smoothing (ASAP)", id="smoothing", panel="timeseries",
   targets=[ts("sum(rate(http_server_requests_seconds_count[5m]))", legend="fleet req/s", refId="A")],
   options={},
   what="Reduces noise in a time series using the ASAP adaptive smoothing algorithm, keeping the shape while removing jitter.",
   demo="Smooths the fleet request-rate series.",
   look="The spiky line becomes a calmer curve that still follows the same trend."),

 dict(slug="spatial", title="Spatial operations", id="spatial", panel="geomap",
   targets=[ts(RATE_BY_SVC_ALL, instant=True, fmt="table")],
   options={"action":"prepare","location":{"mode":"auto"}},
   what="Prepares/derives geometry from your data (points, calculations, transformations) for map visualizations.",
   demo="Runs the spatial 'prepare' action on the service table. (The bank has no lat/long, so this demonstrates the mechanism; a real use feeds coordinate fields into a Geomap.)",
   look="On a Geomap panel, spatial-prepared data becomes plottable points; without coordinates it shows the transform wiring."),
]

# ---- build one dashboard per spec ------------------------------------------
def panel_for(spec):
    p = {
        "id": 1,
        "type": spec["panel"],
        "title": spec["title"],
        "description": spec["what"],
        "gridPos": {"h": 12, "w": 24, "x": 0, "y": 0},
        "datasource": DS,
        "targets": spec["targets"],
        "transformations": [{"id": spec["id"], "options": spec["options"]}],
        "fieldConfig": {"defaults": {}, "overrides": []},
        "options": {},
    }
    if spec["panel"] == "table":
        p["options"] = {"showHeader": True, "cellHeight": "sm"}
    if spec["panel"] == "timeseries":
        p["fieldConfig"]["defaults"] = {"custom": {"drawStyle": "line", "fillOpacity": 8, "showPoints": "never"}}
    return p

def dashboard_for(spec, n):
    return {
        "uid": f"tfx-{spec['slug']}",
        "title": f"TFX {n:02d} · {spec['title']}",
        "tags": ["obs-course", "transformations", spec["slug"]],
        "schemaVersion": 39,
        "editable": True,
        "time": {"from": "now-30m", "to": "now"},
        "refresh": "30s",
        "templating": {"list": []},
        "annotations": {"list": []},
        "panels": [panel_for(spec)],
    }

def main():
    manifest = []
    for i, spec in enumerate(SPECS, 1):
        dash = dashboard_for(spec, i)
        fn = os.path.join(OUT, f"{i:02d}-{spec['slug']}.json")
        with open(fn, "w") as f:
            json.dump(dash, f, indent=2)
        manifest.append((i, spec))
    # README
    lines = []
    lines.append("# Grafana transformations — one example each\n")
    lines.append("A dashboard per Grafana-13 transformation, each with a single panel that\n"
                 "queries the **bankobserve360** Prometheus (datasource uid `prometheus`) and\n"
                 "applies exactly one transformation. Load them all with `make load`.\n")
    lines.append("> Transformations run **client-side in the browser** — open each dashboard in\n"
                 "> Grafana to see the effect. The datasource must be the provisioned bank\n"
                 "> Prometheus (`uid: prometheus`, e.g. from `1.5.1`).\n")
    lines.append("\n## Load\n\n```bash\nmake load GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin\n"
                 "make list      # show what got loaded\nmake delete    # remove them all\n```\n")
    lines.append(f"\n## The {len(SPECS)} transformations\n")
    for i, spec in manifest:
        lines.append(f"\n### {i:02d}. {spec['title']}  ·  `id: {spec['id']}`  ·  uid `tfx-{spec['slug']}`\n")
        lines.append(f"**What it does.** {spec['what']}\n")
        lines.append(f"\n**This example.** {spec['demo']}\n")
        lines.append(f"\n**What to look for.** {spec['look']}\n")
        exprs = " ; ".join(t["expr"] for t in spec["targets"])
        lines.append(f"\n- Panel: `{spec['panel']}`  ·  Query: `{exprs}`\n")
        lines.append(f"- Transform options: `{json.dumps(spec['options'])}`\n")
    with open(os.path.join(HERE, "README.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {len(SPECS)} dashboards to {OUT} and README.md")

if __name__ == "__main__":
    main()
