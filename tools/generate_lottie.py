#!/usr/bin/env python3
"""
Generate Lottie JSON animations for OpenClaw Face.
Each animation has 8 emotion segments of 30 frames each (240 total, 30fps).

Segments:
  0-29:   idle          30-59:  thinking      60-89:  focused
  90-119: responding    120-149: error        150-179: success
  180-209: listening    210-239: sleeping
"""

import json, math, os

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "Shared", "Animations")
W, H = 512, 256
CX, CY = 256, 128

# ════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════

def ease():
    return {"x": [0.4], "y": [1]}

def kf(t, s, e=None):
    if e is None:
        return {"t": t, "s": s if isinstance(s, list) else [s]}
    return {"t": t, "s": s if isinstance(s, list) else [s],
            "e": e if isinstance(e, list) else [e],
            "i": ease(), "o": {"x": [0.5], "y": [0]}}

def sv(v):
    return {"a": 0, "k": v if isinstance(v, list) else [v]}

def anim(keyframes):
    return {"a": 1, "k": keyframes}

def pos_s(x, y):
    return {"a": 0, "k": [x, y, 0]}

def pos_a(kfs):
    r = []
    for i, (t, x, y) in enumerate(kfs):
        if i == len(kfs) - 1:
            r.append({"t": t, "s": [x, y, 0]})
        else:
            r.append({"t": t, "s": [x, y, 0], "e": [kfs[i+1][1], kfs[i+1][2], 0],
                       "i": {"x": 0.4, "y": 1}, "o": {"x": 0.5, "y": 0}})
    return {"a": 1, "k": r}

def sc_a(kfs):
    r = []
    for i, (t, sx, sy) in enumerate(kfs):
        if i == len(kfs) - 1:
            r.append({"t": t, "s": [sx, sy, 100]})
        else:
            r.append({"t": t, "s": [sx, sy, 100], "e": [kfs[i+1][1], kfs[i+1][2], 100],
                       "i": ease(), "o": {"x": [0.5], "y": [0]}})
    return {"a": 1, "k": r}

def op_a(kfs):
    r = []
    for i, (t, op) in enumerate(kfs):
        if i == len(kfs) - 1:
            r.append({"t": t, "s": [op]})
        else:
            r.append({"t": t, "s": [op], "e": [kfs[i+1][1]],
                       "i": ease(), "o": {"x": [0.5], "y": [0]}})
    return {"a": 1, "k": r}

def color_a(kfs):
    """Animated color. kfs: list of (t, r, g, b)"""
    r = []
    for i, (t, cr, cg, cb) in enumerate(kfs):
        if i == len(kfs) - 1:
            r.append({"t": t, "s": [cr, cg, cb, 1]})
        else:
            r.append({"t": t, "s": [cr, cg, cb, 1], "e": [kfs[i+1][1], kfs[i+1][2], kfs[i+1][3], 1],
                       "i": ease(), "o": {"x": [0.5], "y": [0]}})
    return {"a": 1, "k": r}

def ellipse(w, h):
    return {"ty": "el", "d": 1, "s": {"a": 0, "k": [w, h]}, "p": {"a": 0, "k": [0, 0]}}

def rect(w, h, r=0):
    return {"ty": "rc", "d": 1, "s": {"a": 0, "k": [w, h]}, "p": {"a": 0, "k": [0, 0]}, "r": {"a": 0, "k": r}}

def fill_s(r, g, b, op=100):
    return {"ty": "fl", "c": {"a": 0, "k": [r, g, b, 1]}, "o": {"a": 0, "k": op}, "r": 1}

def fill_c(color_kfs, op=100):
    """Fill with animated color."""
    return {"ty": "fl", "c": color_a(color_kfs), "o": {"a": 0, "k": op}, "r": 1}

def stroke_s(r, g, b, w=3, op=100):
    return {"ty": "st", "c": {"a": 0, "k": [r, g, b, 1]}, "o": {"a": 0, "k": op}, "w": {"a": 0, "k": w}, "lc": 2, "lj": 2}

def stroke_c(color_kfs, w=3, op=100):
    return {"ty": "st", "c": color_a(color_kfs), "o": {"a": 0, "k": op}, "w": {"a": 0, "k": w}, "lc": 2, "lj": 2}

def path_shape(vertices, closed=True):
    n = len(vertices)
    return {"ty": "sh", "d": 1, "ks": {"a": 0, "k": {
        "c": closed, "v": vertices,
        "i": [[0,0]]*n, "o": [[0,0]]*n
    }}}

def layer(name, shapes, transform, ind=1):
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1,
            "ks": transform, "ao": 0, "ip": 0, "op": 240, "st": 0, "shapes": shapes}

def tf(x=CX, y=CY, sx=100, sy=100, op=100, rot=0):
    return {"o": sv(op), "r": sv(rot), "p": pos_s(x, y), "a": sv([0, 0, 0]), "s": sv([sx, sy, 100])}

def lottie(name, layers):
    return {"v": "5.7.0", "fr": 30, "ip": 0, "op": 240, "w": W, "h": H, "nm": name, "ddd": 0, "assets": [], "layers": layers}

# ════════════════════════════════════════════
# SHARED KEYFRAMES
# ════════════════════════════════════════════

def eye_scale(blink_y=8):
    return sc_a([
        (0, 100, 100), (12, 100, 100), (14, 100, blink_y), (16, 100, 100), (29, 100, 100),
        (30, 100, 55), (40, 100, 60), (50, 100, 45), (59, 100, 55),
        (60, 100, 25), (75, 100, 30), (89, 100, 25),
        (90, 100, 100), (95, 100, 110), (100, 100, 90), (105, 100, 105), (110, 100, 95), (119, 100, 100),
        (120, 120, 10), (125, 80, 10), (128, 110, 10), (131, 90, 10), (149, 90, 10),
        (150, 120, 120), (155, 130, 130), (165, 115, 115), (179, 120, 120),
        (180, 130, 130), (190, 140, 140), (200, 125, 125), (209, 130, 130),
        (210, 100, 5), (220, 100, 8), (230, 100, 5), (239, 100, 5),
    ])

def eye_pos(bx, by):
    return pos_a([
        (0, bx, by), (29, bx, by),
        (30, bx, by), (36, bx-30, by), (44, bx+30, by), (50, bx, by-15), (55, bx+15, by+10), (59, bx, by),
        (60, bx, by+5), (89, bx, by+5),
        (90, bx, by), (97, bx+5, by-3), (104, bx-5, by+3), (119, bx, by),
        (120, bx, by), (122, bx-12, by), (124, bx+12, by), (126, bx-8, by+5), (128, bx+8, by-5),
        (130, bx-10, by), (132, bx+10, by), (140, bx-6, by), (145, bx+6, by), (149, bx, by),
        (150, bx, by-8), (179, bx, by-5),
        (180, bx, by), (195, bx, by-4), (209, bx, by),
        (210, bx, by+10), (239, bx, by+10),
    ])

# ════════════════════════════════════════════
# AVATARS
# ════════════════════════════════════════════

def make_eyes_round():
    lx, rx, ey = 176, 336, CY
    def mk(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[ellipse(70,70), fill_s(1,1,1)],"nm":"E"}],
            {"o":sv(100),"r":sv(0),"p":eye_pos(bx,ey),"a":sv([0,0,0]),"s":eye_scale()}, ind)
    def pupil(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[ellipse(25,25), fill_s(0,0,0)],"nm":"P"}],
            {"o":op_a([(0,100),(119,100),(120,0),(149,0),(150,100),(239,100)]),
             "r":sv(0),"p":eye_pos(bx,ey),"a":sv([0,0,0]),"s":sv([100,100,100])}, ind)
    return lottie("eyes_round", [mk("L",lx,1), mk("R",rx,2), pupil("LP",lx,3), pupil("RP",rx,4)])

def make_eyes_cyber():
    lx, rx, ey = 176, 336, CY
    def mk(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[rect(55,55,0), stroke_s(0,1,0.5,3), fill_s(0,0.8,0.4,25)],"nm":"D"}],
            {"o":op_a([(0,100),(119,100),(120,100),(123,20),(126,100),(129,20),(132,100),(135,20),(138,80),(149,100),(150,100),(239,100)]),
             "r":anim([kf(0,45),kf(29,45),kf(30,45),kf(40,55),kf(50,35),kf(59,45),kf(60,45),kf(89,45),
                        kf(90,45),kf(95,50),kf(100,40),kf(105,48),kf(119,45),kf(120,45),kf(149,45),
                        kf(150,45),kf(179,45),kf(180,45),kf(209,45),kf(210,45),kf(239,45)]),
             "p":eye_pos(bx,ey),"a":sv([0,0,0]),"s":eye_scale(15)}, ind)
    return lottie("eyes_cyber", [mk("L",lx,1), mk("R",rx,2)])

def make_eyes_minimal():
    lx, rx = 196, 316
    def mk(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[ellipse(30,30), fill_s(1,1,1)],"nm":"D"}],
            {"o":sv(100),"r":sv(0),"p":eye_pos(bx,CY),"a":sv([0,0,0]),
             "s":sc_a([(0,100,100),(12,100,100),(14,100,5),(16,100,100),(29,100,100),
                       (30,70,70),(45,80,80),(59,70,70),(60,50,50),(89,50,50),
                       (90,100,100),(95,120,120),(100,80,80),(105,110,110),(119,100,100),
                       (120,60,60),(125,40,40),(130,80,80),(135,30,30),(149,50,50),
                       (150,120,120),(160,140,140),(179,130,130),
                       (180,150,150),(195,160,160),(209,150,150),
                       (210,40,10),(225,45,15),(239,40,10)])}, ind)
    return lottie("eyes_minimal", [mk("L",lx,1), mk("R",rx,2)])

def make_eyes_neon():
    """Neon colored eyes with color shift per emotion."""
    lx, rx = 176, 336
    emotion_colors = [
        (0, 0, 0.8, 1),     # idle: cyan
        (30, 0.5, 0, 1),    # thinking: purple
        (60, 1, 0.5, 0),    # focused: orange
        (90, 0, 1, 0.5),    # responding: green
        (120, 1, 0, 0),     # error: red
        (150, 1, 1, 0),     # success: yellow
        (180, 0, 0.5, 1),   # listening: blue
        (210, 0.3, 0, 0.6), # sleeping: dim purple
        (239, 0.3, 0, 0.6),
    ]
    def mk(name, bx, ind):
        return layer(name, [
            {"ty":"gr","it":[ellipse(65,65), fill_c(emotion_colors, 90)],"nm":"Glow"},
            {"ty":"gr","it":[ellipse(50,50), fill_s(1,1,1)],"nm":"Core"},
        ], {"o":sv(100),"r":sv(0),"p":eye_pos(bx,CY),"a":sv([0,0,0]),"s":eye_scale()}, ind)
    return lottie("eyes_neon", [mk("L",lx,1), mk("R",rx,2)])

def make_eyes_angry():
    """Angry slanted eyes."""
    lx, rx = 176, 336
    def mk(name, bx, ind, slant):
        return layer(name, [{"ty":"gr","it":[rect(60,25,3), fill_s(1,0.2,0.1)],"nm":"E"}],
            {"o":sv(100),
             "r":anim([kf(0,slant),kf(29,slant),kf(30,slant*1.5),kf(59,slant*1.5),kf(60,slant*2),kf(89,slant*2),
                        kf(90,slant),kf(95,slant*0.5),kf(100,slant),kf(119,slant),
                        kf(120,slant*2),kf(125,slant*2.5),kf(130,slant*1.5),kf(149,slant*2),
                        kf(150,0),kf(179,0),kf(180,slant*0.5),kf(209,slant*0.5),
                        kf(210,slant*0.3),kf(239,slant*0.3)]),
             "p":eye_pos(bx,CY),"a":sv([0,0,0]),
             "s":sc_a([(0,100,100),(12,100,100),(14,100,15),(16,100,100),(29,100,100),
                       (30,100,70),(59,100,70),(60,110,50),(89,110,50),
                       (90,100,100),(95,110,120),(100,90,80),(119,100,100),
                       (120,120,130),(130,110,120),(149,115,125),
                       (150,100,100),(160,120,80),(179,110,90),
                       (180,120,120),(195,130,130),(209,120,120),
                       (210,80,30),(225,85,35),(239,80,30)])}, ind)
    return lottie("eyes_angry", [mk("L",lx,1,-12), mk("R",rx,2,12)])

def make_eyes_cute():
    """Big kawaii eyes with sparkle."""
    lx, rx = 170, 342
    def mk(name, bx, ind):
        return layer(name, [
            {"ty":"gr","it":[ellipse(80,80), fill_s(1,1,1)],"nm":"Eye"},
            {"ty":"gr","it":[ellipse(40,40), fill_s(0.3,0.5,1)],"nm":"Iris"},
            {"ty":"gr","it":[ellipse(20,20), fill_s(0,0,0)],"nm":"Pupil"},
            {"ty":"gr","it":[ellipse(12,12), fill_s(1,1,1)],
             "nm":"Sparkle"},  # sparkle highlight
        ], {"o":sv(100),"r":sv(0),"p":eye_pos(bx,CY),"a":sv([0,0,0]),"s":eye_scale(10)}, ind)
    return lottie("eyes_cute", [mk("L",lx,1), mk("R",rx,2)])

def make_face_robot():
    head = layer("Head", [
        {"ty":"gr","it":[rect(300,200,15), stroke_s(1,1,1,3)],"nm":"H"},
        {"ty":"gr","it":[ellipse(8,8), fill_s(1,1,1,60),
                         {"ty":"tr","p":sv([-135,-85]),"a":sv([0,0]),"s":sv([100,100]),"r":sv(0),"o":sv(100)}],"nm":"S1"},
        {"ty":"gr","it":[ellipse(8,8), fill_s(1,1,1,60),
                         {"ty":"tr","p":sv([135,-85]),"a":sv([0,0]),"s":sv([100,100]),"r":sv(0),"o":sv(100)}],"nm":"S2"},
    ], tf(), ind=1)
    def eye(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[rect(50,50,5), fill_s(1,1,1)],"nm":"RE"}],
            {"o":op_a([(0,100),(119,100),(120,100),(124,30),(128,100),(132,30),(136,100),(149,100),(150,100),(239,100)]),
             "r":sv(0),"p":eye_pos(bx,110),"a":sv([0,0,0]),"s":eye_scale()}, ind)
    mouth = layer("Mouth", [{"ty":"gr","it":[rect(80,8,2), fill_s(1,1,1)],"nm":"M"}],
        {"o":sv(100),"r":sv(0),"p":pos_s(CX,165),"a":sv([0,0,0]),
         "s":sc_a([(0,100,100),(29,100,100),(30,80,80),(59,80,80),(60,120,60),(89,120,60),
                   (90,100,100),(93,100,400),(96,100,80),(99,100,350),(102,100,100),(105,100,300),(108,100,80),(119,100,100),
                   (120,150,200),(125,150,80),(130,150,200),(135,150,80),(149,150,100),
                   (150,140,60),(179,140,60),(180,50,200),(209,50,200),(210,60,40),(239,60,40)])}, ind=4)
    return lottie("face_robot", [head, eye("L",200,2), eye("R",312,3), mouth])

def make_face_cat():
    head = layer("Head", [{"ty":"gr","it":[ellipse(220,190), stroke_s(1,1,1,2.5)],"nm":"H"}], tf(CX,140), ind=1)
    def ear(name, x, verts, ind):
        return layer(name, [{"ty":"gr","it":[path_shape(verts), stroke_s(1,1,1,2.5)],"nm":"E"}],
            {"o":sv(100),
             "r":anim([kf(0,0),kf(29,0),kf(30,0),kf(59,0),kf(60,0),kf(89,0),
                        kf(90,0),kf(95,-8),kf(100,5),kf(105,-5),kf(119,0),
                        kf(120,0),kf(124,-15),kf(128,15),kf(132,-10),kf(149,0),
                        kf(150,-5),kf(179,-3),kf(180,-10),kf(190,-15),kf(200,-8),kf(209,-12),
                        kf(210,8),kf(239,8)]),
             "p":pos_s(x,60),"a":sv([0,0,0]),"s":sv([100,100,100])}, ind)
    def cat_eye(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[ellipse(50,50), fill_s(0.4,0.9,0.3)],"nm":"CE"}],
            {"o":sv(100),"r":sv(0),"p":eye_pos(bx,128),"a":sv([0,0,0]),
             "s":sc_a([(0,100,100),(12,100,100),(14,100,10),(16,100,100),(29,100,100),
                       (30,50,80),(40,45,85),(50,55,75),(59,50,80),(60,30,90),(89,30,90),
                       (90,100,100),(95,110,90),(100,90,110),(119,100,100),
                       (120,80,80),(125,60,60),(130,90,90),(149,70,70),
                       (150,100,50),(160,110,40),(179,105,45),
                       (180,130,130),(195,140,140),(209,130,130),
                       (210,80,5),(225,85,8),(239,80,5)])}, ind)
    nose = layer("Nose", [{"ty":"gr","it":[path_shape([[-6,0],[0,-8],[6,0]]), fill_s(1,0.5,0.6)],"nm":"N"}], tf(CX,150), ind=6)
    return lottie("face_cat", [
        head, ear("LE",188,[[-20,0],[-10,-55],[20,0]],2), ear("RE",324,[[20,0],[10,-55],[-20,0]],3),
        cat_eye("L",210,4), cat_eye("R",302,5), nose])

def make_face_ghost():
    body = layer("Body", [{"ty":"gr","it":[
        path_shape([[-80,60],[-80,-30],[-50,-80],[0,-95],[50,-80],[80,-30],[80,60],
                    [60,45],[40,60],[20,45],[0,60],[-20,45],[-40,60],[-60,45]]),
        fill_s(1,1,1,12), stroke_s(1,1,1,2)],"nm":"G"}],
        {"o":sv(100),"r":sv(0),
         "p":pos_a([(0,CX,138),(15,CX,132),(29,CX,138),(30,CX,138),(45,CX,130),(59,CX,138),
                    (60,CX,138),(89,CX,138),(90,CX,138),(100,CX,128),(110,CX,142),(119,CX,138),
                    (120,CX,138),(125,248,132),(130,264,142),(135,250,130),(140,262,140),(149,CX,138),
                    (150,CX,138),(160,CX,125),(179,CX,130),(180,CX,138),(195,CX,132),(209,CX,138),
                    (210,CX,142),(225,CX,145),(239,CX,142)]),
         "a":sv([0,0,0]),"s":sv([100,100,100])}, ind=1)
    def geye(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[ellipse(35,45), fill_s(1,1,1)],"nm":"GE"}],
            {"o":sv(100),"r":sv(0),"p":eye_pos(bx,115),"a":sv([0,0,0]),"s":eye_scale(8)}, ind)
    mouth = layer("Mouth", [{"ty":"gr","it":[ellipse(25,35), fill_s(0,0,0), stroke_s(1,1,1,1.5)],"nm":"M"}],
        {"o":sv(100),"r":sv(0),"p":pos_s(CX,158),"a":sv([0,0,0]),
         "s":sc_a([(0,80,60),(29,80,60),(30,60,40),(59,60,40),(60,40,30),(89,40,30),
                   (90,100,80),(95,120,140),(100,80,60),(105,110,120),(108,70,50),(119,100,80),
                   (120,150,160),(130,140,150),(149,150,160),
                   (150,120,40),(179,120,35),(180,70,100),(209,70,100),(210,40,20),(239,40,20)])}, ind=4)
    return lottie("face_ghost", [body, geye("L",225,2), geye("R",287,3), mouth])

def make_face_owl():
    def owl_ring(name, bx, ind):
        return layer(name, [
            {"ty":"gr","it":[ellipse(90,90), stroke_s(1,0.8,0.3,2.5)],"nm":"Ring"},
            {"ty":"gr","it":[ellipse(50,50), fill_s(1,0.9,0.4)],"nm":"Eye"},
            {"ty":"gr","it":[ellipse(20,20), fill_s(0,0,0)],"nm":"Pupil"},
        ], {"o":sv(100),"r":sv(0),"p":eye_pos(bx,120),"a":sv([0,0,0]),"s":eye_scale(15)}, ind)
    beak = layer("Beak", [{"ty":"gr","it":[path_shape([[-10,0],[0,18],[10,0]]), fill_s(1,0.7,0.2)],"nm":"B"}], tf(CX,158), ind=3)
    def tuft(name, x, verts, dir, ind):
        return layer(name, [{"ty":"gr","it":[path_shape(verts, False), stroke_s(0.8,0.6,0.2,2)],"nm":"T"}],
            {"o":sv(100),
             "r":anim([kf(0,0),kf(29,0),kf(30,-5*dir),kf(45,5*dir),kf(59,-5*dir),kf(60,0),kf(89,0),
                        kf(90,0),kf(95,-8*dir),kf(100,8*dir),kf(119,0),kf(120,0),kf(125,-15*dir),kf(130,15*dir),kf(149,0),
                        kf(150,-3*dir),kf(179,-3*dir),kf(180,-12*dir),kf(190,-15*dir),kf(200,-8*dir),kf(209,-12*dir),
                        kf(210,5*dir),kf(239,5*dir)]),
             "p":pos_s(x,68),"a":sv([0,0,0]),"s":sv([100,100,100])}, ind)
    return lottie("face_owl", [
        owl_ring("L",205,1), owl_ring("R",307,2), beak,
        tuft("LT",190,[[0,0],[-15,-40],[-5,-50]],1,4), tuft("RT",322,[[0,0],[15,-40],[5,-50]],-1,5)])

def make_face_skull():
    """Skull face — spooky but fun."""
    head = layer("Skull", [{"ty":"gr","it":[
        path_shape([[-70,50],[-75,0],[-70,-40],[-50,-70],[-20,-85],[0,-90],[20,-85],[50,-70],[70,-40],[75,0],[70,50],
                    [50,60],[30,70],[0,75],[-30,70],[-50,60]]),
        stroke_s(1,1,1,2.5), fill_s(1,1,1,8)],"nm":"Skull"}], tf(CX,125), ind=1)
    def sk_eye(name, bx, ind):
        return layer(name, [{"ty":"gr","it":[ellipse(45,55), fill_s(0,0,0), stroke_s(1,1,1,2)],"nm":"SE"}],
            {"o":sv(100),"r":sv(0),"p":eye_pos(bx,110),"a":sv([0,0,0]),
             "s":sc_a([(0,100,100),(12,100,100),(14,100,20),(16,100,100),(29,100,100),
                       (30,80,70),(59,80,70),(60,60,50),(89,60,50),
                       (90,100,100),(95,110,110),(100,90,90),(119,100,100),
                       (120,130,130),(125,80,80),(130,120,120),(135,70,70),(149,100,100),
                       (150,90,80),(179,90,80),(180,120,120),(209,120,120),
                       (210,80,20),(225,85,25),(239,80,20)])}, ind)
    # Teeth
    teeth = layer("Teeth", [
        {"ty":"gr","it":[rect(8,14,1), fill_s(1,1,1),
         {"ty":"tr","p":sv([-24,0]),"a":sv([0,0]),"s":sv([100,100]),"r":sv(0),"o":sv(100)}],"nm":"T1"},
        {"ty":"gr","it":[rect(8,14,1), fill_s(1,1,1),
         {"ty":"tr","p":sv([-12,0]),"a":sv([0,0]),"s":sv([100,100]),"r":sv(0),"o":sv(100)}],"nm":"T2"},
        {"ty":"gr","it":[rect(8,14,1), fill_s(1,1,1),
         {"ty":"tr","p":sv([0,0]),"a":sv([0,0]),"s":sv([100,100]),"r":sv(0),"o":sv(100)}],"nm":"T3"},
        {"ty":"gr","it":[rect(8,14,1), fill_s(1,1,1),
         {"ty":"tr","p":sv([12,0]),"a":sv([0,0]),"s":sv([100,100]),"r":sv(0),"o":sv(100)}],"nm":"T4"},
        {"ty":"gr","it":[rect(8,14,1), fill_s(1,1,1),
         {"ty":"tr","p":sv([24,0]),"a":sv([0,0]),"s":sv([100,100]),"r":sv(0),"o":sv(100)}],"nm":"T5"},
    ], {"o":sv(100),"r":sv(0),"p":pos_s(CX,168),"a":sv([0,0,0]),
        "s":sc_a([(0,100,100),(29,100,100),(30,100,80),(59,100,80),(60,100,100),(89,100,100),
                  (90,100,100),(95,100,130),(100,100,80),(105,100,120),(119,100,100),
                  (120,100,100),(125,120,150),(130,80,60),(135,110,130),(149,100,100),
                  (150,120,80),(179,120,80),(180,80,100),(209,80,100),(210,100,60),(239,100,60)])}, ind=4)
    nose = layer("Nose", [{"ty":"gr","it":[path_shape([[-5,0],[0,-8],[5,0]]), fill_s(0,0,0), stroke_s(1,1,1,1.5)],"nm":"N"}],
        tf(CX,148), ind=5)
    return lottie("face_skull", [head, sk_eye("L",220,2), sk_eye("R",292,3), teeth, nose])

def make_face_alien():
    """Alien face — big head, huge dark eyes."""
    head = layer("Head", [{"ty":"gr","it":[ellipse(250,200), stroke_s(0.5,1,0.5,2), fill_s(0.2,0.6,0.3,15)],"nm":"H"}],
        tf(CX,135), ind=1)
    def alien_eye(name, bx, ind):
        return layer(name, [
            {"ty":"gr","it":[ellipse(70,90), fill_s(0,0,0)],"nm":"AE"},
            {"ty":"gr","it":[ellipse(70,90), stroke_s(0.3,0.9,0.4,2)],"nm":"AER"},
            {"ty":"gr","it":[ellipse(15,15), fill_s(0.3,1,0.4,80)],"nm":"Glow"},
        ], {"o":sv(100),"r":sv(0),"p":eye_pos(bx,118),"a":sv([0,0,0]),
            "s":sc_a([(0,100,100),(12,100,100),(14,100,70),(16,100,100),(29,100,100),
                      (30,90,80),(45,95,85),(59,90,80),(60,80,60),(89,80,60),
                      (90,100,100),(95,105,110),(100,95,90),(119,100,100),
                      (120,110,110),(125,90,90),(130,115,115),(135,85,85),(149,100,100),
                      (150,105,95),(179,105,95),(180,120,120),(195,125,125),(209,120,120),
                      (210,90,50),(225,92,55),(239,90,50)])}, ind)
    mouth = layer("Mouth", [{"ty":"gr","it":[ellipse(15,8), fill_s(0.3,0.9,0.4,60)],"nm":"M"}],
        {"o":sv(100),"r":sv(0),"p":pos_s(CX,168),"a":sv([0,0,0]),
         "s":sc_a([(0,60,60),(29,60,60),(30,40,40),(59,40,40),(60,30,20),(89,30,20),
                   (90,80,80),(95,120,150),(100,60,50),(105,100,130),(119,80,80),
                   (120,150,200),(130,100,100),(149,140,180),
                   (150,100,40),(179,100,40),(180,50,80),(209,50,80),(210,30,20),(239,30,20)])}, ind=4)
    return lottie("face_alien", [head, alien_eye("L",205,2), alien_eye("R",307,3), mouth])

# ════════════════════════════════════════════
# SPHERE (Siri-like glowing RGB orb)
# ════════════════════════════════════════════

def make_sphere_rgb():
    """Siri-like glowing sphere with RGB color cycling per emotion."""
    # Color palettes per emotion segment
    # Each layer cycles through colors at different speeds
    layer1_colors = [
        (0,   1, 0.2, 0.5),   # idle: pinkish
        (8,   0.5, 0.2, 1),   # shift to purple
        (16,  0.2, 0.8, 1),   # shift to cyan
        (24,  1, 0.2, 0.5),   # back
        (29,  1, 0.2, 0.5),
        (30,  0.3, 0.3, 1),   # thinking: deep blue cycling
        (38,  0.6, 0.2, 1),
        (46,  0.2, 0.4, 1),
        (54,  0.5, 0.3, 0.9),
        (59,  0.3, 0.3, 1),
        (60,  1, 0.6, 0),     # focused: warm orange
        (70,  1, 0.4, 0.1),
        (80,  1, 0.7, 0.2),
        (89,  1, 0.5, 0),
        (90,  0, 1, 0.6),     # responding: lively green-cyan
        (97,  0.2, 0.8, 1),
        (104, 0, 1, 0.4),
        (111, 0.3, 0.9, 0.8),
        (119, 0, 1, 0.6),
        (120, 1, 0, 0),       # error: angry red
        (126, 1, 0.1, 0.1),
        (132, 0.8, 0, 0),
        (138, 1, 0.2, 0),
        (144, 1, 0, 0.1),
        (149, 1, 0, 0),
        (150, 1, 0.8, 0),     # success: golden
        (158, 1, 1, 0.3),
        (166, 0.9, 0.7, 0.1),
        (174, 1, 0.9, 0.4),
        (179, 1, 0.8, 0),
        (180, 0, 0.5, 1),     # listening: calm blue
        (190, 0.2, 0.6, 1),
        (200, 0, 0.4, 0.9),
        (209, 0, 0.5, 1),
        (210, 0.15, 0.05, 0.3), # sleeping: very dim purple
        (220, 0.1, 0.05, 0.25),
        (230, 0.15, 0.08, 0.3),
        (239, 0.15, 0.05, 0.3),
    ]

    layer2_colors = [
        (0,   0.2, 0.5, 1),
        (10,  0.8, 0.2, 1),
        (20,  0.3, 1, 0.8),
        (29,  0.2, 0.5, 1),
        (30,  0.5, 0.1, 1),
        (42,  0.2, 0.3, 0.9),
        (54,  0.6, 0.1, 0.8),
        (59,  0.5, 0.1, 1),
        (60,  1, 0.3, 0.1),
        (75,  0.9, 0.5, 0),
        (89,  1, 0.3, 0.1),
        (90,  0.3, 1, 0.3),
        (100, 0, 0.8, 0.6),
        (110, 0.4, 1, 0.2),
        (119, 0.3, 1, 0.3),
        (120, 0.9, 0.2, 0),
        (130, 1, 0, 0.2),
        (140, 0.8, 0.1, 0),
        (149, 0.9, 0.2, 0),
        (150, 0.8, 1, 0.2),
        (165, 1, 0.9, 0),
        (179, 0.8, 1, 0.2),
        (180, 0.1, 0.3, 0.9),
        (195, 0.2, 0.5, 1),
        (209, 0.1, 0.3, 0.9),
        (210, 0.1, 0, 0.2),
        (225, 0.08, 0.02, 0.18),
        (239, 0.1, 0, 0.2),
    ]

    layer3_colors = [
        (0,   0.5, 1, 0.5),
        (12,  1, 0.5, 0.8),
        (24,  0.5, 0.8, 1),
        (29,  0.5, 1, 0.5),
        (30,  0.4, 0.2, 0.8),
        (45,  0.3, 0.4, 1),
        (59,  0.4, 0.2, 0.8),
        (60,  0.8, 0.6, 0.1),
        (75,  1, 0.5, 0.2),
        (89,  0.8, 0.6, 0.1),
        (90,  0.1, 0.8, 1),
        (105, 0.5, 1, 0.5),
        (119, 0.1, 0.8, 1),
        (120, 1, 0.3, 0.3),
        (135, 0.9, 0, 0.1),
        (149, 1, 0.3, 0.3),
        (150, 1, 0.6, 0.1),
        (165, 0.9, 1, 0.3),
        (179, 1, 0.6, 0.1),
        (180, 0.3, 0.6, 1),
        (195, 0.1, 0.4, 0.8),
        (209, 0.3, 0.6, 1),
        (210, 0.08, 0.03, 0.15),
        (225, 0.12, 0.05, 0.2),
        (239, 0.08, 0.03, 0.15),
    ]

    # Outer glow ring
    ring_outer = layer("Glow Outer", [
        {"ty":"gr","it":[ellipse(200,200), fill_c(layer1_colors, 20)],"nm":"GO"},
    ], {"o":sv(100),"r":sv(0),"p":pos_s(CX,CY),"a":sv([0,0,0]),
        "s":sc_a([(0,100,100),(7,102,102),(14,98,98),(21,101,101),(29,100,100),
                  (30,95,95),(40,100,100),(50,95,95),(59,97,97),
                  (60,90,90),(75,92,92),(89,90,90),
                  (90,100,100),(95,108,108),(100,94,94),(105,106,106),(110,96,96),(115,103,103),(119,100,100),
                  (120,110,110),(124,85,85),(128,115,115),(132,80,80),(136,110,110),(140,90,90),(149,100,100),
                  (150,105,105),(160,115,115),(170,108,108),(179,110,110),
                  (180,100,100),(190,104,104),(200,98,98),(209,100,100),
                  (210,85,85),(220,87,87),(230,85,85),(239,85,85)])}, ind=1)

    # Middle sphere
    sphere_mid = layer("Sphere Mid", [
        {"ty":"gr","it":[ellipse(140,140), fill_c(layer2_colors, 50)],"nm":"SM"},
    ], {"o":sv(100),"r":sv(0),"p":pos_s(CX,CY),"a":sv([0,0,0]),
        "s":sc_a([(0,100,100),(10,103,103),(20,97,97),(29,100,100),
                  (30,96,96),(42,100,100),(54,95,95),(59,97,97),
                  (60,92,92),(75,94,94),(89,92,92),
                  (90,100,100),(95,106,106),(100,95,95),(105,104,104),(119,100,100),
                  (120,108,108),(126,88,88),(132,112,112),(138,85,85),(144,105,105),(149,100,100),
                  (150,103,103),(162,110,110),(174,105,105),(179,108,108),
                  (180,100,100),(192,103,103),(204,99,99),(209,100,100),
                  (210,88,88),(222,90,90),(234,88,88),(239,88,88)])}, ind=2)

    # Core bright
    sphere_core = layer("Sphere Core", [
        {"ty":"gr","it":[ellipse(80,80), fill_c(layer3_colors, 80)],"nm":"SC"},
    ], {"o":sv(100),"r":sv(0),"p":pos_s(CX,CY),"a":sv([0,0,0]),
        "s":sc_a([(0,100,100),(8,105,105),(16,95,95),(24,102,102),(29,100,100),
                  (30,98,98),(38,102,102),(46,96,96),(54,100,100),(59,98,98),
                  (60,94,94),(72,96,96),(84,93,93),(89,94,94),
                  (90,100,100),(94,108,108),(98,93,93),(102,106,106),(106,95,95),(110,103,103),(114,97,97),(119,100,100),
                  (120,105,105),(124,85,85),(128,110,110),(132,82,82),(136,108,108),(140,88,88),(149,100,100),
                  (150,102,102),(158,112,112),(166,105,105),(174,110,110),(179,108,108),
                  (180,100,100),(188,104,104),(196,98,98),(204,102,102),(209,100,100),
                  (210,90,90),(218,92,92),(226,89,89),(234,91,91),(239,90,90)])}, ind=3)

    # Bright center highlight
    highlight = layer("Highlight", [
        {"ty":"gr","it":[ellipse(30,30), fill_s(1,1,1,60)],"nm":"HL"},
    ], {"o":op_a([(0,60),(29,60),(30,40),(59,40),(60,30),(89,30),
                  (90,60),(95,80),(100,50),(105,70),(119,60),
                  (120,80),(125,30),(130,90),(135,20),(149,50),
                  (150,70),(160,90),(179,80),
                  (180,60),(195,50),(209,55),
                  (210,20),(225,25),(239,20)]),
         "r":sv(0),"p":pos_s(CX-15,CY-15),"a":sv([0,0,0]),
         "s":sc_a([(0,100,100),(15,110,110),(29,100,100),
                   (30,80,80),(45,90,90),(59,80,80),
                   (60,60,60),(89,60,60),
                   (90,100,100),(95,120,120),(100,90,90),(119,100,100),
                   (120,80,80),(130,60,60),(149,70,70),
                   (150,110,110),(165,130,130),(179,120,120),
                   (180,100,100),(195,105,105),(209,100,100),
                   (210,50,50),(225,55,55),(239,50,50)])}, ind=4)

    return lottie("sphere_rgb", [ring_outer, sphere_mid, sphere_core, highlight])


# ════════════════════════════════════════════
# GENERATE ALL
# ════════════════════════════════════════════

os.makedirs(OUT_DIR, exist_ok=True)

# Note: full-head avatars (face_robot, face_cat, face_ghost, face_owl,
# face_skull, face_alien) and the RGB sphere have been removed as part of
# the avatar pivot. The bot now expresses itself through eyes-with-mimicry
# (Custom renderer) and abstract avatars (AbstractFaceView). The legacy
# make_face_*() functions are still in this file as a reference, but they
# are no longer registered in the output map.
avatars = {
    "eyes_round": make_eyes_round(),
    "eyes_cyber": make_eyes_cyber(),
    "eyes_minimal": make_eyes_minimal(),
    "eyes_neon": make_eyes_neon(),
    "eyes_angry": make_eyes_angry(),
    "eyes_cute": make_eyes_cute(),
}

for name, data in avatars.items():
    path = os.path.join(OUT_DIR, f"{name}.json")
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    size = os.path.getsize(path)
    print(f"  {name}.json ({size:,} bytes)")

print(f"\nGenerated {len(avatars)} animations in {OUT_DIR}")
