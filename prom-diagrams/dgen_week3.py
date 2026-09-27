#!/usr/bin/env python3
"""Generate Week 3 diagrams (JPEG) in the course's visual language."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle
import numpy as np, os

OUT = os.path.dirname(os.path.abspath(__file__))
DPI = 120
NAVY="#0f2a43"; CRIMSON="#C7254E"; GREEN="#2e7d46"; GREY="#5f6b76"
AMBER="#8a6d1a"; LBLBG="#eef1f6"; OKBG="#eef4ef"; AMBBG="#fbf3df"; CRBG="#fbeef1"
INK="#22303c"; MUT="#5f6b76"
plt.rcParams.update({"font.family":"DejaVu Sans","font.size":13})

def canvas(w, h):
    fig = plt.figure(figsize=(w, h), dpi=DPI)
    ax = fig.add_axes([0,0,1,1]); H=100*h/w
    ax.set_xlim(0,100); ax.set_ylim(0,H); ax.axis("off")
    fig.patch.set_facecolor("white")
    return fig, ax, H

def box(ax, x, y, w, h, title="", sub="", fill=LBLBG, edge=NAVY, tc=NAVY, tsz=14, ssz=10.5, lw=1.6, bold=True):
    ax.add_patch(FancyBboxPatch((x,y), w, h, boxstyle="round,pad=0.02,rounding_size=1.0",
                 fc=fill, ec=edge, lw=lw, mutation_aspect=1))
    if title and sub:
        ax.text(x+w/2, y+h*0.60, title, ha="center", va="center", color=tc, fontsize=tsz, fontweight="bold" if bold else "normal")
        ax.text(x+w/2, y+h*0.26, sub, ha="center", va="center", color=MUT, fontsize=ssz)
    elif title:
        ax.text(x+w/2, y+h/2, title, ha="center", va="center", color=tc, fontsize=tsz, fontweight="bold" if bold else "normal")

def arrow(ax, x1, y1, x2, y2, color=CRIMSON, lw=2.2):
    ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2), arrowstyle="-|>", mutation_scale=17,
                 color=color, lw=lw, shrinkA=2, shrinkB=2))

def title(ax, H, t, s=""):
    ax.text(3.5, H-2.6, t, ha="left", va="center", color=NAVY, fontsize=18, fontweight="bold")
    if s: ax.text(3.5, H-6.6, s, ha="left", va="center", color=MUT, fontsize=12)
    return H-9.5   # content top

def save(fig, name):
    fig.savefig(os.path.join(OUT,name), format="jpeg", dpi=DPI, pil_kwargs={"quality":93})
    plt.close(fig); print("wrote", name)

# 1. slo-nines --------------------------------------------------------------
def d_nines():
    fig, ax, H = canvas(16, 8.0); ct = title(ax, H, "The cost of each nine",
        "Every added nine cuts the downtime budget 10x — and roughly doubles the cost to hold it.")
    xh=8; wpct=15; wbud=30; wcost=22
    ax.text(xh+wpct/2, ct-1, "SLO target", ha="center", color=MUT, fontsize=11.5, fontweight="bold")
    ax.text(xh+wpct+6+wbud/2, ct-1, "Downtime budget / month", ha="center", color=MUT, fontsize=11.5, fontweight="bold")
    ax.text(xh+wpct+6+wbud+6+wcost/2, ct-1, "Relative cost", ha="center", color=MUT, fontsize=11.5, fontweight="bold")
    rows=[("99%","7h 12m","1x baseline",LBLBG),("99.9%","43m","~3x",OKBG),
          ("99.99%","4.3m","~15x",AMBBG),("99.999%","26s","~50x+",CRBG)]
    top=ct-7.5
    for i,(pct,bud,cost,bg) in enumerate(rows):
        yy=top-i*6.6; h=5.4
        box(ax, xh, yy, wpct, h, pct, fill=NAVY, edge=NAVY, tc="white", tsz=15)
        box(ax, xh+wpct+6, yy, wbud, h, bud, fill=bg, edge=AMBER, tc=INK, tsz=14, bold=False)
        box(ax, xh+wpct+6+wbud+6, yy, wcost, h, cost, fill=bg, edge=CRIMSON, tc=CRIMSON, tsz=14)
    save(fig, "slo-nines.jpg")

# 2. burn-windows -----------------------------------------------------------
def d_burn():
    fig, ax, H = canvas(16, 8.2); ct = title(ax, H, "Multi-window, multi-burn-rate alerting",
        "Two windows must agree: a long window confirms it is real, a short sentinel confirms it is still happening.")
    cols=["Severity","Burn rate","Long window","Short sentinel","Budget spent"]
    xs=[6,24,42,60,78]; wcol=16.5
    for x,c in zip(xs,cols):
        ax.text(x+wcol/2, ct-1, c, ha="center", color=MUT, fontsize=11.3, fontweight="bold")
    rows=[("PAGE","14.4x","1 h","5 m","2% in 1h",CRBG,CRIMSON),
          ("PAGE","6x","6 h","30 m","5% in 6h",CRBG,CRIMSON),
          ("TICKET","3x","1 d","2 h","10% in 1d",AMBBG,AMBER),
          ("TICKET","1x","3 d","6 h","budget pace",AMBBG,AMBER)]
    top=ct-7.5
    for i,(sev,br,lw_,sw,spent,bg,ec) in enumerate(rows):
        yy=top-i*6.6; h=5.4
        box(ax, xs[0], yy, wcol, h, sev, fill=ec, edge=ec, tc="white", tsz=13)
        for x,val in zip(xs[1:], [br,lw_,sw,spent]):
            box(ax, x, yy, wcol, h, val, fill=bg, edge=ec, tc=INK, tsz=13, bold=False)
    save(fig, "burn-windows.jpg")

# 3. severity-ladder --------------------------------------------------------
def d_severity():
    fig, ax, H = canvas(16, 7.6); ct = title(ax, H, "The alert severity ladder",
        "Map urgency to a response time — and keep the page channel sacred.")
    rows=[("PAGE / SEV1","Active customer impact — wakes a human","respond ~5 min",CRIMSON,CRBG),
          ("WARNING / SEV2","Impact imminent","respond ~30 min",AMBER,AMBBG),
          ("TICKET / SEV3","Real, can wait for business hours","next business day",GREEN,OKBG),
          ("INFO / SEV4","Logged for context","notifies no one",GREY,LBLBG)]
    top=ct-1
    for i,(name,desc,rt,ec,bg) in enumerate(rows):
        yy=top-i*7.4; h=6.0
        box(ax, 7, yy, 27, h, name, fill=ec, edge=ec, tc="white", tsz=13.5)
        box(ax, 36, yy, 40, h, desc, fill=bg, edge=ec, tc=INK, tsz=12, bold=False)
        box(ax, 78, yy, 16, h, rt, fill="white", edge=ec, tc=ec, tsz=11.5)
    save(fig, "severity-ladder.jpg")

# 4. alertmanager-flow ------------------------------------------------------
def d_am():
    fig, ax, H = canvas(16, 7.0); ct = title(ax, H, "Alertmanager — from firing rule to the right human",
        "Prometheus decides when an alert fires; Alertmanager decides what happens next.")
    cy=(ct+3)/2
    box(ax, 3.5, cy-6, 15, 12, "Prometheus", "fires alerts", fill=LBLBG, edge=NAVY, tsz=13.5)
    box(ax, 29, cy-12, 30, 24, fill="#f7f9fb", edge=NAVY, tsz=15)
    ax.text(44, cy+9.5, "Alertmanager", ha="center", color=NAVY, fontsize=14, fontweight="bold")
    for i,j in enumerate(["group","route","inhibit","silence","dedupe"]):
        box(ax, 31.5, cy+6-i*3.4, 25, 2.9, j, fill=LBLBG, edge=GREY, tc=INK, tsz=11, lw=1.0, bold=False)
    arrow(ax, 18.5, cy, 29, cy, NAVY)
    recv=[("PagerDuty","severity=page",CRIMSON,CRBG),("Slack","mirror",GREEN,OKBG),("Jira","severity=ticket",AMBER,AMBBG)]
    for i,(r,tag,ec,bg) in enumerate(recv):
        yy=cy+8-i*8
        box(ax, 72, yy-3, 22, 6, r, tag, fill=bg, edge=ec, tc=ec, tsz=12.5)
        arrow(ax, 59, cy, 72, yy, ec, lw=1.7)
    save(fig, "alertmanager-flow.jpg")

# 5. investigation-funnel ---------------------------------------------------
def d_funnel():
    fig, ax, H = canvas(16, 7.0); ct = title(ax, H, "The investigation funnel",
        "Wide to narrow — each hop should be one click, not a cross-tab hunt.")
    cy=(ct-2+6)/2
    stages=[("METRIC","where? — something is wrong",NAVY,21,22),
            ("TRACE","which hop? — the failing span",AMBER,18,18),
            ("LOG","what? — the exact error line",GREEN,15.5,14),
            ("CODE","the fix",CRIMSON,13,10)]
    x=4
    for i,(name,q,ec,w,h) in enumerate(stages):
        yy=cy-h/2
        box(ax, x, yy, w, h, name, fill="white", edge=ec, tc=ec, tsz=15)
        ax.text(x+w/2, yy-2.4, q, ha="center", va="top", color=MUT, fontsize=10.5)
        if i<3:
            nw=stages[i+1][3]
            arrow(ax, x+w+0.4, cy, x+w+5.6, cy, ec, lw=2.3)
        x+=w+6
    save(fig, "investigation-funnel.jpg")

# 6. exemplar-pipeline ------------------------------------------------------
def d_exemplar():
    fig, ax, H = canvas(16, 6.8); ct = title(ax, H, "The exemplar pipeline: metric to trace",
        "Four switches in a row — miss one and the dots never appear.")
    cy=(ct-2+5)/2
    stages=[("OTel SDK","emit exemplars",NAVY),("Collector","export",NAVY),
            ("Prometheus","exemplar-storage",CRIMSON),("Grafana","trace destination",NAVY),("Trace","one click in",GREEN)]
    x=3.5; w=16.5; gap=2.2; h=11
    for i,(name,sub,ec) in enumerate(stages):
        box(ax, x, cy-h/2, w, h, name, fill=OKBG if i==4 else LBLBG, edge=ec, tsz=13)
        ax.text(x+w/2, cy-h/2-2.2, sub, ha="center", va="top", color=MUT, fontsize=9.8)
        if i<4: arrow(ax, x+w+0.1, cy, x+w+gap-0.1, cy, GREY, lw=1.9)
        x+=w+gap
    save(fig, "exemplar-pipeline.jpg")

# 7. k8s-sources ------------------------------------------------------------
def d_k8ssrc():
    fig, ax, H = canvas(16, 7.2); ct = title(ax, H, "The five Kubernetes metrics sources",
        "Each source owns a different question — scraping the wrong one is the classic mistake.")
    srcs=[("cAdvisor","per-container"),("Node Exporter","per-host"),
          ("kube-state-metrics","object state"),("metrics-server","HPA only"),("control plane","apiserver / etcd")]
    x=3.2; w=17.2; gap=1.3; ytop=ct-2; h=11
    for i,(n,s) in enumerate(srcs):
        ec = CRIMSON if i==2 else (GREY if i==3 else NAVY)
        box(ax, x, ytop-h, w, h, n, s, fill=LBLBG, edge=ec, tsz=12.3, ssz=10)
        arrow(ax, x+w/2, ytop-h-0.2, 50, 11.5, GREY, lw=1.2)
        x+=w+gap
    box(ax, 38, 4, 24, 7.5, "Prometheus", fill=NAVY, edge=NAVY, tc="white", tsz=14)
    save(fig, "k8s-sources.jpg")

# 8. operator-crds ----------------------------------------------------------
def d_operator():
    fig, ax, H = canvas(16, 6.8); ct = title(ax, H, "The Prometheus Operator CRDs",
        "Scrape config and rules become Kubernetes objects — GitOps-able alongside the apps.")
    crds=[("ServiceMonitor","scrape Services"),("PodMonitor","scrape Pods"),("PrometheusRule","recording + alerts")]
    ytop=ct-2
    for i,(n,s) in enumerate(crds):
        yy=ytop-8 - i*9.5
        box(ax, 5, yy, 24, 7.5, n, s, fill=LBLBG, edge=NAVY, tsz=12.5, ssz=10)
        arrow(ax, 29, yy+3.7, 40, (ytop-16)/2+7, GREY, lw=1.5)
    cy=(ytop-16)/2+7
    box(ax, 40, cy-6.5, 22, 13, "Prometheus\nOperator", "watches release: kps", fill=AMBBG, edge=AMBER, tc=INK, tsz=12.5, ssz=10)
    arrow(ax, 62, cy, 72, cy, NAVY)
    box(ax, 72, cy-6.5, 22, 13, "Prometheus", "reloaded config", fill=NAVY, edge=NAVY, tc="white", tsz=14)
    save(fig, "operator-crds.jpg")

# 9. synthetic-vs-rum -------------------------------------------------------
def d_synrum():
    fig, ax, H = canvas(16, 6.8); ct = title(ax, H, "Synthetic vs RUM — the outside-in view",
        "White-box can read green while no real user can reach you. You need both.")
    cy=(ct-2+6)/2
    box(ax, 45, cy-6, 12, 12, "Your\nservice", fill=NAVY, edge=NAVY, tc="white", tsz=13)
    box(ax, 6, cy-2, 21, 8, "Synthetic", "robot you control", fill=OKBG, edge=GREEN, tc=GREEN, tsz=13.5)
    ax.text(16.5, cy-5, "scheduled probes • is it UP?\navailability • cert expiry • zero traffic", ha="center", va="top", color=MUT, fontsize=10)
    arrow(ax, 27, cy+2, 45, cy+2, GREEN, lw=2)
    box(ax, 75, cy-2, 21, 8, "RUM", "real users' browsers", fill=CRBG, edge=CRIMSON, tc=CRIMSON, tsz=13.5)
    ax.text(85.5, cy-5, "Core Web Vitals • is it GOOD?\nreal devices, networks, regions", ha="center", va="top", color=MUT, fontsize=10)
    arrow(ax, 75, cy+2, 57, cy+2, CRIMSON, lw=2)
    save(fig, "synthetic-vs-rum.jpg")

# 10. slo-lifecycle ---------------------------------------------------------
def d_lifecycle():
    fig, ax, H = canvas(16, 6.8); ct = title(ax, H, "The SLO lifecycle: healthy, outage, recovery",
        "Drive the SLO through the three states an on-call actually sees.")
    base=10; peak=ct-6
    for x0,x1,lab,c,bg in [(8,38,"HEALTHY",GREEN,OKBG),(38,62,"OUTAGE",CRIMSON,CRBG),(62,94,"RECOVERY",AMBER,AMBBG)]:
        ax.add_patch(Rectangle((x0,base-1),x1-x0,(peak+3)-(base-1), fc=bg, ec="none", alpha=0.30, zorder=0))
        ax.text((x0+x1)/2, peak+2.4, lab, ha="center", color=c, fontsize=12.5, fontweight="bold")
    ax.plot([8,94],[base,base], color=GREY, lw=1)
    ax.text(6.5, base, "SLI", ha="right", va="center", color=MUT, fontsize=10.5)
    amp=peak-base-2
    xs=np.linspace(8,94,300)
    ys=np.piecewise(xs,[xs<38,(xs>=38)&(xs<62),xs>=62],
        [lambda x:base+0.4+0.25*np.sin(x),
         lambda x:base+0.4+amp*(1-np.exp(-(x-38)/4.0)),
         lambda x:base+0.4+(amp+2)*np.exp(-(x-62)/6.0)])
    ax.plot(xs,ys, color=CRIMSON, lw=2.6)
    ax.text(23, base+3.5, "SLI ≈ 0\nnothing fires", ha="center", color=GREEN, fontsize=10)
    ax.text(50, base+amp+0.5, "UpiSLOFastBurn\npages ~2 min", ha="center", va="bottom", color=CRIMSON, fontsize=10)
    ax.text(81, base+6, "short window clears\nalert self-resolves", ha="center", color=AMBER, fontsize=10)
    save(fig, "slo-lifecycle.jpg")

for f in (d_nines,d_burn,d_severity,d_am,d_funnel,d_exemplar,d_k8ssrc,d_operator,d_synrum,d_lifecycle):
    f()
print("ALL WEEK3 DIAGRAMS DONE")
