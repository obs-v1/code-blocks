# Grafana transformations — one example each

A dashboard per Grafana-13 transformation, each with a single panel that
queries the **bankobserve360** Prometheus (datasource uid `prometheus`) and
applies exactly one transformation. Load them all with `make load`.

> Transformations run **client-side in the browser** — open each dashboard in
> Grafana to see the effect. The datasource must be the provisioned bank
> Prometheus (`uid: prometheus`, e.g. from `1.5.1`).


## Load

```bash
make load GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
make list      # show what got loaded
make delete    # remove them all
```


## The 34 transformations


### 01. Reduce  ·  `id: reduce`  ·  uid `tfx-reduce`

**What it does.** Collapses each time series down to a single number per calculation — turning a range of points into one summary value.


**This example.** Six per-service request-rate series go in; the transform outputs a table with one row per series and a column for each reducer (last, mean, max).


**What to look for.** Instead of lines over time you get a compact table: Field | Last | Mean | Max.


- Panel: `table`  ·  Query: `topk(6, sum by (service) (rate(http_server_requests_seconds_count[5m])))`

- Transform options: `{"reducers": ["last", "mean", "max"], "mode": "reduceFields", "includeTimeField": false}`


### 02. Add field from calculation  ·  `id: calculateField`  ·  uid `tfx-calculate-field`

**What it does.** Creates a NEW field by calculating across existing fields — a binary op (A/B, A-B), a row reduction (sum of fields), or a scalar op.


**This example.** The per-service rate table gains a computed column 'Value ×100' = Value × 100 (a scalar binary op).


**What to look for.** A new numeric column appears beside Value, each cell 100× the original.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"mode": "binary", "binary": {"left": "Value", "operator": "*", "right": "100"}, "alias": "Value \u00d7100", "replaceFields": false}`


### 03. Organize fields by name  ·  `id: organize`  ·  uid `tfx-organize`

**What it does.** Rename, reorder, and hide columns from a single query — the everyday 'make this table presentable' transform.


**This example.** Hides the Time column and renames service→Service and Value→'Requests / sec'.


**What to look for.** A tidy two-column table with human headers; the raw Time column is gone.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"excludeByName": {"Time": true}, "indexByName": {}, "renameByName": {"service": "Service", "Value": "Requests / sec"}}`


### 04. Filter fields by name  ·  `id: filterFieldsByName`  ·  uid `tfx-filter-fields-by-name`

**What it does.** Keeps or drops whole columns (fields) by name, regex, or dashboard variable.


**This example.** The raw table has service, outcome and Value columns; the regex 'service|Value' keeps only service and Value.


**What to look for.** The outcome column disappears; only service and Value remain.


- Panel: `table`  ·  Query: `sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"include": {"pattern": "service|Value"}}`


### 05. Filter data by values  ·  `id: filterByValue`  ·  uid `tfx-filter-by-value`

**What it does.** Keeps or drops individual ROWS based on a condition on a field's value.


**This example.** Keeps only rows where Value (req/s) is greater than 0.1 — the busier services.


**What to look for.** Low-traffic services drop out; only rows above the 0.1 req/s threshold survive.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"type": "include", "match": "any", "filters": [{"fieldName": "Value", "config": {"id": "greater", "options": {"value": 0.1}}}]}`


### 06. Filter data by query refId  ·  `id: filterByRefId`  ·  uid `tfx-filter-by-refid`

**What it does.** In a multi-query panel, hides the results of whole queries by their refId — without deleting the query.


**This example.** Two queries (A = total, B = errors) both run; the transform includes only refId A.


**What to look for.** Query B's rows are hidden even though it still executes; only A is shown.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m])) ; sum by (service) (rate(http_server_requests_seconds_count{outcome!="SUCCESS"}[5m]))`

- Transform options: `{"include": "A"}`


### 07. Rename by regex  ·  `id: renameByRegex`  ·  uid `tfx-rename-by-regex`

**What it does.** Renames field (column/series) names using a regex match and replacement pattern.


**This example.** Each series is named by its service (account-service, auth-service, …). The pattern (.*)-service → $1 strips the '-service' suffix.


**What to look for.** Column/series names shorten: 'account-service' becomes 'account'.


- Panel: `table`  ·  Query: `topk(6, sum by (service) (rate(http_server_requests_seconds_count[5m])))`

- Transform options: `{"regex": "(.*)-service", "renamePattern": "$1"}`


### 08. Sort by  ·  `id: sortBy`  ·  uid `tfx-sort-by`

**What it does.** Sorts the rows of each frame by a chosen field, ascending or descending.


**This example.** Sorts the per-service table by Value descending — busiest service first.


**What to look for.** Rows reorder so the highest req/s is on top.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"sort": [{"field": "Value", "desc": true}]}`


### 09. Limit  ·  `id: limit`  ·  uid `tfx-limit`

**What it does.** Caps the number of rows shown, for a focused view of the first N.


**This example.** Shows only the first 5 rows of the per-service table.


**What to look for.** At most five services appear, however many the query returned.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"limitField": 5}`


### 10. Labels to fields  ·  `id: labelsToFields`  ·  uid `tfx-labels-to-fields`

**What it does.** Turns time-series labels (service, outcome, …) into their own table columns (or rows).


**This example.** A time series labelled by service and outcome becomes a table with explicit service and outcome columns plus the value.


**What to look for.** Labels that were hidden inside the series legend become first-class columns.


- Panel: `table`  ·  Query: `sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"mode": "columns", "keepLabels": ["service", "outcome"]}`


### 11. Series to rows  ·  `id: seriesToRows`  ·  uid `tfx-series-to-rows`

**What it does.** Merges multiple time-series results into one long table of Time | Metric | Value rows.


**This example.** Six per-service series are stacked into a single three-column table, one row per (time, series, value).


**What to look for.** One tall table with a Metric column naming which series each value came from.


- Panel: `table`  ·  Query: `topk(6, sum by (service) (rate(http_server_requests_seconds_count[5m])))`

- Transform options: `{}`


### 12. Join by field  ·  `id: joinByField`  ·  uid `tfx-join-by-field`

**What it does.** Merges several results into one wide table by matching on a shared field (a SQL-style outer/inner join).


**This example.** Query A (total rate) and B (error rate) are joined on the service column into one row per service with both values.


**What to look for.** One table: service | Value 1 (total) | Value 2 (errors) — the two queries side by side.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m])) ; sum by (service) (rate(http_server_requests_seconds_count{outcome!="SUCCESS"}[5m]))`

- Transform options: `{"byField": "service", "mode": "outer"}`


### 13. Join by labels  ·  `id: joinByLabels`  ·  uid `tfx-join-by-labels`

**What it does.** Joins multiple time series into one wide table using their shared labels as the join keys.


**This example.** Series labelled by service+outcome are pivoted so each outcome becomes a column, keyed by the remaining labels.


**What to look for.** A wide table keyed by label with one column per outcome value.


- Panel: `table`  ·  Query: `sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"value": "outcome"}`


### 14. Merge series/tables  ·  `id: merge`  ·  uid `tfx-merge`

**What it does.** Combines the rows of multiple queries/tables into a single result, aligning shared columns.


**This example.** The total-rate table and the error-rate table are merged into one combined table.


**What to look for.** Rows from both queries appear in one table, matching columns lined up.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m])) ; sum by (service) (rate(http_server_requests_seconds_count{outcome!="SUCCESS"}[5m]))`

- Transform options: `{}`


### 15. Concatenate fields  ·  `id: concatenate`  ·  uid `tfx-concatenate`

**What it does.** Pulls every field from multiple frames into one frame, placing them side by side.


**This example.** All columns from the two queries are concatenated into a single wide frame.


**What to look for.** One frame containing the fields of both queries together.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m])) ; sum by (service) (rate(http_server_requests_seconds_count{outcome!="SUCCESS"}[5m]))`

- Transform options: `{"frameNameMode": "field", "frameNameLabel": "frame"}`


### 16. Prepare time series  ·  `id: prepareTimeSeries`  ·  uid `tfx-prepare-time-series`

**What it does.** Converts time-series data between 'wide' (one column per series) and 'long' (tidy) formats so a visualization can read it.


**This example.** The per-service series are reshaped to the wide multi-frame format many panels expect.


**What to look for.** The lines render normally; the transform fixes frame shape rather than changing the picture.


- Panel: `timeseries`  ·  Query: `topk(6, sum by (service) (rate(http_server_requests_seconds_count[5m])))`

- Transform options: `{"format": "wide"}`


### 17. Time series to table  ·  `id: timeSeriesTable`  ·  uid `tfx-time-series-to-table`

**What it does.** Converts time-series results into a table with a sparkline cell summarising each series' trend.


**This example.** Each per-service series becomes one table row with a mini trend (sparkline) cell.


**What to look for.** A row per service with a tiny inline chart of its recent rate.


- Panel: `table`  ·  Query: `topk(6, sum by (service) (rate(http_server_requests_seconds_count[5m])))`

- Transform options: `{}`


### 18. Transpose  ·  `id: transpose`  ·  uid `tfx-transpose`

**What it does.** Pivots the table — rows become columns and columns become rows.


**This example.** The service/Value table is flipped so services become column headers.


**What to look for.** What was a tall two-column table becomes a wide one-row-per-metric table.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{}`


### 19. Group by  ·  `id: groupBy`  ·  uid `tfx-group-by`

**What it does.** Groups rows by a field and applies calculations (sum, count, mean, …) to the others — like SQL GROUP BY.


**This example.** Groups the service/outcome/Value table by outcome and sums+counts the Value per outcome.


**What to look for.** One row per outcome (SUCCESS, CLIENT_ERROR, …) with summed and counted request rate.


- Panel: `table`  ·  Query: `sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"fields": {"outcome": {"aggregations": [], "operation": "groupby"}, "Value": {"aggregations": ["sum", "count"], "operation": "aggregate"}}}`


### 20. Grouping to matrix  ·  `id: groupingToMatrix`  ·  uid `tfx-grouping-to-matrix`

**What it does.** Builds a matrix/pivot table from three fields: one becomes rows, one becomes columns, one fills the cells.


**This example.** service → rows, outcome → columns, Value → cells: a service×outcome matrix of request rates.


**What to look for.** A grid with services down the side, outcomes across the top, rates in the cells.


- Panel: `table`  ·  Query: `sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"columnField": "outcome", "rowField": "service", "valueField": "Value"}`


### 21. Group to nested tables  ·  `id: groupToNestedTable`  ·  uid `tfx-group-to-nested-table`

**What it does.** Groups rows and tucks the members of each group into an expandable nested sub-table.


**This example.** Groups by service; each service row expands to reveal its per-outcome rows.


**What to look for.** A collapsed table of services; click a row to expand its outcome breakdown.


- Panel: `table`  ·  Query: `sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"fields": {"service": {"aggregations": [], "operation": "groupby"}}}`


### 22. Partition by values  ·  `id: partitionByValues`  ·  uid `tfx-partition-by-values`

**What it does.** Splits one result into several frames, one per unique value of the chosen field.


**This example.** Partitions the table by outcome, producing a separate frame for SUCCESS, CLIENT_ERROR, etc.


**What to look for.** Multiple frames/tables, each holding only the rows for one outcome.


- Panel: `table`  ·  Query: `sum by (service, outcome) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"fields": ["outcome"], "keepFields": false, "naming": {"asLabels": false}}`


### 23. Rows to fields  ·  `id: rowsToFields`  ·  uid `tfx-rows-to-fields`

**What it does.** Turns each row into its own field — using one column for the field NAME and another for its VALUE (and even config).


**This example.** Each service row becomes a named field whose value is its request rate; a Stat panel then shows one big number per service.


**What to look for.** Instead of a table, a row of stat tiles, one per service, labelled by service name.


- Panel: `stat`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"mappings": [{"fieldName": "service", "handlerKey": "field.name"}, {"fieldName": "Value", "handlerKey": "field.value"}]}`


### 24. Config from query results  ·  `id: configFromData`  ·  uid `tfx-config-from-query`

**What it does.** Reads standard options (Max, Min, Unit, Thresholds) from one query and applies them to another query's fields.


**This example.** Query A returns a constant (1) used as the Max; query B's per-service rates are then gauged against that Max.


**What to look for.** The gauges are scaled to the Max supplied by query A rather than an auto-range.


- Panel: `gauge`  ·  Query: `vector(1) ; sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"configRefId": "A", "mappings": [{"fieldName": "Value", "handlerKey": "max"}]}`


### 25. Convert field type  ·  `id: convertFieldType`  ·  uid `tfx-convert-field-type`

**What it does.** Changes a field's type — number, string, time, boolean, or enum — so downstream transforms/panels treat it correctly.


**This example.** Converts the numeric Value column to a string.


**What to look for.** Value renders left-aligned as text rather than a right-aligned number.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"conversions": [{"targetField": "Value", "destinationType": "string"}]}`


### 26. Extract fields  ·  `id: extractFields`  ·  uid `tfx-extract-fields`

**What it does.** Parses a source field (JSON, key=value, or regex) and pulls out new fields from inside it.


**This example.** Applies regex (?<team>.*)-service to the service column, extracting a new 'team' field.


**What to look for.** A new 'team' column appears with the service name minus its suffix.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"source": "service", "format": "regex", "regExp": "(?<team>.*)-service", "keepTime": false, "replace": false}`


### 27. Format string  ·  `id: formatString`  ·  uid `tfx-format-string`

**What it does.** Reformats a string field — upper/lower/title case, trim, or substring.


**This example.** Upper-cases the service column.


**What to look for.** Service names render in ALL CAPS.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"stringField": "service", "substringStart": 0, "substringEnd": 100, "outputFormat": "Upper Case"}`


### 28. Format time  ·  `id: formatTime`  ·  uid `tfx-format-time`

**What it does.** Formats a time field with a Moment.js pattern so timestamps read the way you want.


**This example.** Formats the Time column as 'YYYY-MM-DD HH:mm:ss'.


**What to look for.** The Time column shows friendly, fully-formatted timestamps.


- Panel: `table`  ·  Query: `topk(6, sum by (service) (rate(http_server_requests_seconds_count[5m])))`

- Transform options: `{"timeField": "Time", "outputFormat": "YYYY-MM-DD HH:mm:ss", "useTimezone": true}`


### 29. Lookup fields from resource  ·  `id: fieldLookup`  ·  uid `tfx-field-lookup`

**What it does.** Enriches a field by looking values up in a gazetteer (e.g. country/US-state → coordinates & names).


**This example.** Attempts to look up the service field against the built-in countries gazetteer. (Bank services aren't countries, so this mostly shows the mechanism / how a non-match behaves.)


**What to look for.** Extra lookup columns are added where a value matches the gazetteer; a real use would query a field of country codes.


- Panel: `table`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"lookupField": "service", "gazetteer": "public/gazetteer/countries.json"}`


### 30. Histogram  ·  `id: histogram`  ·  uid `tfx-histogram`

**What it does.** Buckets the input values and counts how many fall in each bucket — a distribution of the numbers themselves.


**This example.** Takes the per-service request rates and bins them into a histogram of 'how many services run at each rate'.


**What to look for.** A bar chart of value buckets vs count, computed by Grafana from the series.


- Panel: `histogram`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"bucketSize": null, "bucketOffset": 0, "combine": false}`


### 31. Create heatmap  ·  `id: heatmap`  ·  uid `tfx-heatmap`

**What it does.** Calculates a heatmap (x/y bucketed density) from ordinary series inside Grafana — distinct from Prometheus-side histogram buckets.


**This example.** Grafana buckets the per-service rate series over time into a calculated heatmap.


**What to look for.** A time × value density grid coloured by count.


- Panel: `heatmap`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"xBuckets": {"mode": "count", "value": ""}, "yBuckets": {"mode": "count", "value": ""}}`


### 32. Trendline (regression)  ·  `id: regression`  ·  uid `tfx-regression`

**What it does.** Fits a linear or polynomial regression to the data and draws the predicted trendline alongside it.


**This example.** Adds a straight-line linear trend over the noisy fleet request-rate series.


**What to look for.** The jagged rate line gains a smooth straight trendline showing its direction.


- Panel: `timeseries`  ·  Query: `sum(rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"modelType": "linear", "predictionCount": 100}`


### 33. Smoothing (ASAP)  ·  `id: smoothing`  ·  uid `tfx-smoothing`

**What it does.** Reduces noise in a time series using the ASAP adaptive smoothing algorithm, keeping the shape while removing jitter.


**This example.** Smooths the fleet request-rate series.


**What to look for.** The spiky line becomes a calmer curve that still follows the same trend.


- Panel: `timeseries`  ·  Query: `sum(rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{}`


### 34. Spatial operations  ·  `id: spatial`  ·  uid `tfx-spatial`

**What it does.** Prepares/derives geometry from your data (points, calculations, transformations) for map visualizations.


**This example.** Runs the spatial 'prepare' action on the service table. (The bank has no lat/long, so this demonstrates the mechanism; a real use feeds coordinate fields into a Geomap.)


**What to look for.** On a Geomap panel, spatial-prepared data becomes plottable points; without coordinates it shows the transform wiring.


- Panel: `geomap`  ·  Query: `sum by (service) (rate(http_server_requests_seconds_count[5m]))`

- Transform options: `{"action": "prepare", "location": {"mode": "auto"}}`

