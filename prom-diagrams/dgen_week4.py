#!/usr/bin/env python3
"""Generate Week 4 diagrams (JPEG) in the course's visual language."""
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle
import os
OUT = os.path.dirname(os.path.abspath(__file__)); DPI=120
NAVY="#0f2a43"; CRIMSON="#C7254E"; GREEN="#2e7d46"; GREY="#5f6b76"
AMBER="#8a6d1a"; LBLBG="#eef1f6"; OKBG="#eef4ef"; AMBBG="#fbf3df"; CRBG="#fbeef1"
INK="#22303c"; MUT="#5f6b76"
plt.rcParams.update({"font.family":"DejaVu Sans","font.size":13})

def canvas(w,h):
    fig=plt.figure(figsize=(w,h),dpi=DPI); ax=fig.add_axes([0,0,1,1]); H=100*h/w
    ax.set_xlim(0,100); ax.set_ylim(0,H); ax.axis("off"); fig.patch.set_facecolor("white")
    return fig,ax,H
def box(ax,x,y,w,h,title="",sub="",fill=LBLBG,edge=NAVY,tc=NAVY,tsz=14,ssz=10.5,lw=1.6,bold=True):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.02,rounding_size=1.0",fc=fill,ec=edge,lw=lw,mutation_aspect=1))
    if title and sub:
        ax.text(x+w/2,y+h*0.60,title,ha="center",va="center",color=tc,fontsize=tsz,fontweight="bold" if bold else "normal")
        ax.text(x+w/2,y+h*0.26,sub,ha="center",va="center",color=MUT,fontsize=ssz)
    elif title:
        ax.text(x+w/2,y+h/2,title,ha="center",va="center",color=tc,fontsize=tsz,fontweight="bold" if bold else "normal")
def flat_rect(ax,x,y,w,h,label,fill,edge,tc=INK,tsz=12):
    ax.add_patch(Rectangle((x,y),w,h,fc=fill,ec=edge,lw=1.4))
    ax.text(x+w/2,y+h/2,label,ha="center",va="center",color=tc,fontsize=tsz,fontweight="bold")
def arrow(ax,x1,y1,x2,y2,color=CRIMSON,lw=2.2):
    ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2),arrowstyle="-|>",mutation_scale=17,color=color,lw=lw,shrinkA=2,shrinkB=2))
def title(ax,H,t,s=""):
    ax.text(3.5,H-2.6,t,ha="left",va="center",color=NAVY,fontsize=18,fontweight="bold")
    if s: ax.text(3.5,H-6.6,s,ha="left",va="center",color=MUT,fontsize=12)
    return H-9.5
def save(fig,name):
    fig.savefig(os.path.join(OUT,name),format="jpeg",dpi=DPI,pil_kwargs={"quality":93}); plt.close(fig); print("wrote",name)

# 1. flame-graph ------------------------------------------------------------
def d_flame():
    fig,ax,H=canvas(16,7.0); ct=title(ax,H,"Reading a flame graph",
        "Width is resource share; the vertical axis is just the call stack. Read the wide tops, not the wide bottoms.")
    y=5; h=4.2
    flat_rect(ax,6,y,88,h,"main()  —  on the stack for everything",LBLBG,NAVY,MUT,11)
    flat_rect(ax,6,y+h,52,h,"handleRequest()",LBLBG,NAVY,INK,11.5)
    flat_rect(ax,60,y+h,20,h,"router()",LBLBG,GREY,INK,11)
    flat_rect(ax,6,y+2*h,52,h,"renderStatement()",AMBBG,AMBER,INK,11.5)
    flat_rect(ax,6,y+3*h,52,h,"deriveStatementKey()",AMBBG,AMBER,INK,11.5)
    flat_rect(ax,6,y+4*h,52,h,"pbkdf2Sync()   ← the hot top",CRBG,CRIMSON,CRIMSON,12)
    ax.annotate("wide frame at the TOP\n= where the CPU runs", xy=(32,y+5*h), xytext=(64,y+4.4*h),
        ha="center",color=CRIMSON,fontsize=11, arrowprops=dict(arrowstyle="-|>",color=CRIMSON,lw=1.8))
    ax.text(50, y-2.4, "width  =  % of CPU time", ha="center", color=MUT, fontsize=11)
    save(fig,"flame-graph.jpg")

# 2. ebpf-layers ------------------------------------------------------------
def d_ebpf():
    fig,ax,H=canvas(16,6.8); ct=title(ax,H,"What eBPF sees — below the application",
        "eBPF observes from the kernel, so it needs no app changes — but it cannot see business context.")
    ax.add_patch(Rectangle((5,ct-11),90,10,fc=OKBG,ec=GREEN,lw=1.4))
    ax.text(9,ct-2.2,"USER SPACE",color=GREEN,fontsize=11,fontweight="bold")
    box(ax,10,ct-9.5,36,6.5,"Application + OTel SDK","sees: user_id, tenant, journey",fill="white",edge=GREEN,tc=GREEN,tsz=12,ssz=9.5)
    ax.text(72,ct-6,"business context\nlives only here",ha="center",color=GREEN,fontsize=10.5)
    ax.add_patch(Rectangle((5,ct-24),90,11,fc=LBLBG,ec=NAVY,lw=1.4))
    ax.text(9,ct-14.4,"KERNEL  —  eBPF",color=NAVY,fontsize=11,fontweight="bold")
    for i,s in enumerate(["TCP retransmits","scheduling delay","page faults","DNS timing","syscall latency","L7 parsing"]):
        box(ax,8+i*14.5,ct-22.5,13.2,5.2,s,fill="white",edge=NAVY,tc=INK,tsz=9.6,bold=False)
    arrow(ax,50,ct-13,50,ct-11.2,GREY,lw=1.6)
    ax.text(52,ct-12.3,"no app changes",ha="left",va="center",color=MUT,fontsize=10)
    save(fig,"ebpf-layers.jpg")

# 3. incident-lifecycle -----------------------------------------------------
def d_lifecycle():
    fig,ax,H=canvas(16,6.6); ct=title(ax,H,"The incident lifecycle",
        "Mitigation stops the pain and comes first; resolution fixes the cause and can wait.")
    stages=[("PAGE","",NAVY),("ACK","≤5 min",NAVY),("ASSESS","blast radius",NAVY),
            ("MITIGATE","stop the pain",CRIMSON),("RESOLVE","root cause",GREEN),("POSTMORTEM","learn",AMBER)]
    cy=(ct-2+5)/2; x=3.5; w=13.5; gap=1.6
    for i,(n,s,ec) in enumerate(stages):
        box(ax,x,cy-4,w,8,n,s,fill=CRBG if ec==CRIMSON else (OKBG if ec==GREEN else (AMBBG if ec==AMBER else LBLBG)),edge=ec,tc=ec,tsz=12.5,ssz=9.8)
        if i<5: arrow(ax,x+w+0.1,cy,x+w+gap-0.1,cy,GREY,lw=1.8)
        x+=w+gap
    ax.annotate("30-min rule:\nno progress → change the plan", xy=(3.5+3*(w+gap)+w/2, cy-4.2), xytext=(50, cy-8.6),
        ha="center", color=CRIMSON, fontsize=10.5, arrowprops=dict(arrowstyle="-|>",color=CRIMSON,lw=1.6))
    save(fig,"incident-lifecycle.jpg")

# 4. cost-drivers -----------------------------------------------------------
def d_cost():
    fig,ax,H=canvas(16,6.8); ct=title(ax,H,"The three telemetry cost drivers",
        "Attribute a runaway bill to one driver before touching anything — each has a distinct lever.")
    cy=(ct-2+6)/2
    ax.text(8,cy,"COST  =",ha="center",va="center",color=NAVY,fontsize=16,fontweight="bold")
    drivers=[("Cardinality","unique label combos","lever: labeldrop,\nrecording rules",NAVY),
             ("Log volume","bytes ingested","lever: drop noise,\nsample, retention",GREEN),
             ("Traces × retention","spans × days","lever: tail sampling,\nspan budget",AMBER)]
    x=17; w=23; gap=3
    for i,(n,s,lev,ec) in enumerate(drivers):
        box(ax,x,cy-5.5,w,11,n,s,fill=LBLBG,edge=ec,tc=ec,tsz=13,ssz=10)
        ax.text(x+w/2,cy-8.4,lev,ha="center",va="top",color=MUT,fontsize=9.8)
        if i<2: ax.text(x+w+gap/2,cy,"+",ha="center",va="center",color=NAVY,fontsize=16,fontweight="bold")
        x+=w+gap
    save(fig,"cost-drivers.jpg")

# 5. fail-open-trap ---------------------------------------------------------
def d_trap():
    fig,ax,H=canvas(16,6.8); ct=title(ax,H,"The fail-open trap — a green SLO is not a healthy system",
        "Payments succeed whether fraud screening runs or not, so the availability SLO never moves.")
    cy=ct-2
    box(ax,5,cy-6.5,17,6,"Payment","request",fill=LBLBG,edge=NAVY,tsz=13)
    # normal path
    box(ax,32,cy-3,20,5.2,"fraud check OK","",fill=OKBG,edge=GREEN,tc=GREEN,tsz=11.5)
    box(ax,62,cy-3,16,5.2,"COMPLETED","",fill=OKBG,edge=GREEN,tc=GREEN,tsz=12)
    arrow(ax,22,cy-3.5,32,cy-0.4,GREEN,1.7); arrow(ax,52,cy-0.4,62,cy-0.4,GREEN,1.7)
    # fail-open path
    box(ax,32,cy-11,20,5.2,"fraud check DOWN",'"(allowing)"',fill=CRBG,edge=CRIMSON,tc=CRIMSON,tsz=11,ssz=9.5)
    box(ax,62,cy-11,16,5.2,"COMPLETED","fraud_score: 0",fill=CRBG,edge=CRIMSON,tc=CRIMSON,tsz=12,ssz=9.5)
    arrow(ax,22,cy-4.5,32,cy-8.4,CRIMSON,1.7); arrow(ax,52,cy-8.4,62,cy-8.4,CRIMSON,1.7)
    box(ax,84,cy-8,13,6,"SLO","stays GREEN",fill=OKBG,edge=GREEN,tc=GREEN,tsz=12,ssz=9.8)
    ax.text(70,cy-13.6,"only a log line — 'fraud check failed (allowing)' — reveals the policy gap",
        ha="center",color=CRIMSON,fontsize=10.5)
    save(fig,"fail-open-trap.jpg")

for f in (d_flame,d_ebpf,d_lifecycle,d_cost,d_trap): f()
print("ALL WEEK4 DIAGRAMS DONE")
