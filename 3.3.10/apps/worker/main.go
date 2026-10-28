// worker — the downstream Go service in the 3.3.10 four-signal lab.
//
// The gateway calls us; we do the CPU-hot work and emit all four signals:
//
//	traces + metrics + logs  →  OTLP  →  OTel Collector  →  Jaeger / Prometheus / Loki
//	CPU & alloc profiles     →  pyroscope-go SDK  →  Pyroscope
//
// The tracer provider is wrapped by otelpyroscope so EVERY span carries a
// `pyroscope.profile.id` resource/attribute — that id is the trace → code
// (flame-graph) join Grafana follows from a span to its profile.
//
// Fault injection is env-driven (flipped by `kubectl set env`, see the Makefile):
//
//	BURN_LOOPS   how many sha256 rounds computeScore() grinds through (the hot frame)
//	ERROR_RATE   fraction of requests that fail downstream (0.0–1.0)
package main

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	otelpyroscope "github.com/grafana/otel-profiling-go"
	"github.com/grafana/pyroscope-go"

	"go.opentelemetry.io/contrib/bridges/otelslog"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/log"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	oteltrace "go.opentelemetry.io/otel/trace"
)

const service = "worker"

var logger *slog.Logger

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func main() {
	ctx := context.Background()

	// One resource identifies this service across all three signals — the shared
	// tags (service.name, namespace, version) that make correlation joins work.
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(service),
			semconv.ServiceVersion(env("VERSION", "1.0.0")),
			semconv.ServiceNamespace("monitoring"),
			semconv.DeploymentEnvironment("lab"),
		),
	)
	if err != nil {
		panic(err)
	}

	otlp := env("OTEL_EXPORTER_OTLP_ENDPOINT", "otel-collector:4317")

	// ── traces ──────────────────────────────────────────────────────────────
	texp, err := otlptracegrpc.New(ctx, otlptracegrpc.WithEndpoint(otlp), otlptracegrpc.WithInsecure())
	if err != nil {
		panic(err)
	}
	tp := trace.NewTracerProvider(trace.WithBatcher(texp), trace.WithResource(res))
	// Wrap so every span gets a pyroscope.profile.id — the trace→profile join.
	otel.SetTracerProvider(otelpyroscope.NewTracerProvider(tp))
	// Without this, Go's global propagator is a no-op: otelhttp would IGNORE the
	// gateway's traceparent header and start a NEW trace, so gateway→worker never
	// joins. This single line is what makes "which hop?" work across the two services.
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{}))
	defer tp.Shutdown(ctx)

	// ── metrics (otelhttp records http.server.request.duration with exemplars) ─
	mexp, err := otlpmetricgrpc.New(ctx, otlpmetricgrpc.WithEndpoint(otlp), otlpmetricgrpc.WithInsecure())
	if err != nil {
		panic(err)
	}
	mp := metric.NewMeterProvider(
		metric.WithResource(res),
		metric.WithReader(metric.NewPeriodicReader(mexp, metric.WithInterval(5*time.Second))),
	)
	otel.SetMeterProvider(mp)
	defer mp.Shutdown(ctx)

	// ── logs (JSON, with code.* source attrs → the log→code caller field) ─────
	lexp, err := otlploggrpc.New(ctx, otlploggrpc.WithEndpoint(otlp), otlploggrpc.WithInsecure())
	if err != nil {
		panic(err)
	}
	lp := log.NewLoggerProvider(log.WithResource(res), log.WithProcessor(log.NewBatchProcessor(lexp)))
	defer lp.Shutdown(ctx)
	// AddSource stamps source=file:line on every record — that is the log→code hop.
	logger = otelslog.NewLogger(service, otelslog.WithLoggerProvider(lp), otelslog.WithSource(true))

	// ── profiles (pyroscope-go SDK → Pyroscope, independent of the Collector) ─
	pyroscope.Start(pyroscope.Config{
		ApplicationName: service,
		ServerAddress:   env("PYROSCOPE_SERVER", "http://pyroscope:4040"),
		Tags:            map[string]string{"namespace": "monitoring", "version": env("VERSION", "1.0.0")},
		ProfileTypes: []pyroscope.ProfileType{
			pyroscope.ProfileCPU, pyroscope.ProfileAllocObjects, pyroscope.ProfileAllocSpace,
			pyroscope.ProfileInuseObjects, pyroscope.ProfileInuseSpace,
		},
	})

	mux := http.NewServeMux()
	mux.Handle("/process", otelhttp.NewHandler(http.HandlerFunc(process), "process"))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprintln(w, "ok") })

	logger.Info("worker up", "addr", ":8080", "otlp", otlp)
	if err := http.ListenAndServe(":8080", mux); err != nil {
		panic(err)
	}
}

// process handles one unit of work: a CPU-hot score, then a maybe-failing debit.
func process(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	score := computeScore(ctx) // the hot frame the flame graph will point at

	errorRate, _ := strconv.ParseFloat(env("ERROR_RATE", "0"), 64)
	if rand.Float64() < errorRate {
		// The error log line names the cause and (via source=) the code that logged it.
		logger.ErrorContext(ctx, "debit failed: downstream declined",
			"score", score, "reason", "insufficient_funds")
		oteltrace.SpanFromContext(ctx).RecordError(errors.New("downstream declined"))
		http.Error(w, `{"error":"debit failed"}`, http.StatusInternalServerError)
		return
	}

	logger.InfoContext(ctx, "debit ok", "score", score)
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"ok","score":%d}`, score)
}

// computeScore is deliberately CPU-bound: it grinds sha256 BURN_LOOPS times.
// Under fault, BURN_LOOPS climbs and this frame dominates the flame graph —
// the whole point of the trace→code pivot.
func computeScore(ctx context.Context) int {
	_, span := otel.Tracer(service).Start(ctx, "computeScore")
	defer span.End()

	loops, _ := strconv.Atoi(env("BURN_LOOPS", "20000"))
	span.SetAttributes(attribute.Int("burn.loops", loops))

	buf := []byte("bankobs-score-seed")
	var acc byte
	for i := 0; i < loops; i++ {
		h := sha256.Sum256(buf)
		buf = h[:]
		acc += h[0]
	}
	return int(acc)
}
