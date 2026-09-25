//
//  AriaOrb.metal
//  AriaLite
//
//  La sfera di Aria: porting in Metal dello shader "Glass Liquid" (new-blob-v0.3-b_w.html),
//  solo il preset usato dall'app — stile 19, la membrana vocale — con il guscio di vetro.
//  I parametri arrivano come un array di float nello stesso ordine dell'HTML (vedi AriaOrb.swift):
//  scalari da 0 a 39, poi i colori RGBA a partire da 40.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

namespace orb {

// Indici dei parametri (struct Uniforms dell'HTML).
constant int SIZE_X = 0, SIZE_Y = 1, TIME = 2, SPEED = 3, RADIUS = 4, ZOOM = 5, WARP = 6, RIDGE = 7,
             SHADE = 9, SHEEN = 10, GLOSS = 11, SHELL_MID_A = 12, SHELL_EDGE_A = 13, EXPOSURE = 14,
             EDGE_SOFT = 16, EDGE_GLOW = 17, GLASS_OPACITY = 20, CONTOUR = 21;
constant int COLOR_A = 40, COLOR_B = 44, COLOR_C = 48, COLOR_D = 52, HIGHLIGHT = 56, SHELL_INNER = 60,
             SHELL_MID = 64, SHELL_EDGE = 68, SHEEN_C = 72, SPEC_C = 76, CANVAS = 80, GLOW_C = 84;

struct U {
    device const float *v;
    float f(int i) const { return v[i]; }
    float3 c(int i) const { return float3(v[i], v[i + 1], v[i + 2]); }
};

// pow senza NaN sulla base zero (fast math).
float spow(float x, float y) { return x <= 0.0 ? 0.0 : pow(x, y); }

// ── Bordo (mfEdgeD / mfEdgeGlow) ────────────────────────────────────────────
float edgeD(float soft) { return soft - 0.005; }

float3 edgeGlow(float3 col, float2 uv, float rad, float soft, float glow, float3 glowRGB) {
    if (glow <= 0.0) { return col; }
    float r = length(uv);
    float outside = smoothstep(rad - max(soft, 0.0005), rad + max(soft, 0.0005), r);
    return col + glowRGB * (glow * exp(-max(r - rad, 0.0) * 11.0) * outside);
}

// ── Fluido: membrana vocale (glsVoiceWaveFluid + glsFinishPresetFluid) ──────
float3 finishPreset(float3 color, float2 p, U u) {
    float shade = u.f(SHADE);
    color = mix(color, u.c(HIGHLIGHT), shade * 0.22 * smoothstep(0.15, 1.15, dot(p, float2(-0.32, 0.78))));
    color *= 1.0 - shade * 0.34 * smoothstep(-0.1, 1.2, dot(p, float2(0.45, -0.62)));
    color *= 1.0 - shade * 0.22 * smoothstep(0.72, 1.08, length(p));
    return clamp(color, 0.0, 1.0);
}

float3 voiceWave(float2 p, float t, U u) {
    float scale = 0.76 + u.f(ZOOM) * 0.34;
    float2 q = p / scale;
    float rimEnvelope = spow(max(1.0 - q.x * q.x, 0.0), 0.72);
    float drift = t * 0.82;
    float amplitude = 0.2 + u.f(WARP) * 0.018;
    float mainY = rimEnvelope * (amplitude * sin(q.x * 1.48 + drift) + 0.055 * sin(q.x * 3.2 - drift * 0.43 + 1.1));
    float distance = q.y - mainY;
    float width = 0.11 + (1.0 - u.f(RIDGE)) * 0.075;
    float membrane = exp(-distance * distance / max(width * width, 0.001)) * rimEnvelope;
    float upperVeil = exp(-(distance - 0.105) * (distance - 0.105) / max(width * width * 2.4, 0.001)) * rimEnvelope;
    float lowerVeil = exp(-(distance + 0.115) * (distance + 0.115) / max(width * width * 2.8, 0.001)) * rimEnvelope;
    float crest = exp(-distance * distance / 0.0026) * rimEnvelope;
    float depth = sqrt(max(1.0 - clamp(dot(p, p), 0.0, 1.0), 0.0));
    float3 color = mix(u.c(COLOR_A) * 0.7, u.c(COLOR_D) * 0.34, smoothstep(-0.82, 0.82, q.y));
    color = mix(color, u.c(COLOR_B), upperVeil * 0.7);
    color = mix(color, u.c(COLOR_C), lowerVeil * 0.62);
    color += mix(u.c(COLOR_B), u.c(COLOR_C), 0.46) * membrane * 0.34;
    color += u.c(HIGHLIGHT) * crest * 0.14;
    color *= 0.58 + 0.42 * depth;
    return finishPreset(color, p, u);
}

// ── Contorno che respira (glsContourWave / Scale / Normal, ramo stile 19) ──
float2 contourWave(float angle, float t) {
    float wave = sin(angle * 2.0 + t * 0.27) * 0.72 + sin(angle * 4.0 - t * 0.16 + 2.1) * 0.28;
    float slope = cos(angle * 2.0 + t * 0.27) * 1.44 + cos(angle * 4.0 - t * 0.16 + 2.1) * 1.12;
    return float2(wave, slope);
}

constant float CONTOUR_STRENGTH = 0.11;

float contourScale(float2 uv, float t, float amount) {
    if (amount <= 0.0) { return 1.0; }
    return 1.0 + clamp(amount, 0.0, 1.0) * CONTOUR_STRENGTH * contourWave(atan2(uv.y, uv.x), t).x;
}

float2 contourNormal(float2 uv, float rad, float t, float amount) {
    float d = length(uv);
    if (d <= 0.0001) { return float2(0.0); }
    float2 radial = uv / d;
    float slope = clamp(amount, 0.0, 1.0) * CONTOUR_STRENGTH * contourWave(atan2(uv.y, uv.x), t).y;
    float2 tangent = float2(-radial.y, radial.x);
    return normalize(radial - tangent * (rad * slope / d));
}

// ── Guscio di vetro ─────────────────────────────────────────────────────────
float3 over(float3 dst, float3 src, float a) {
    float k = clamp(a, 0.0, 1.0);
    return src * k + dst * (1.0 - k);
}

float refractionProfile(float t) {
    float depth = clamp(t, 0.0, 1.0);
    return 1.0 - sqrt(max(1.0 - (1.0 - depth) * (1.0 - depth), 0.0));
}

float highlightLobe(float2 normal, float2 direction, float cut, float power) {
    float angular = clamp((dot(normal, direction) - cut) / max(1.0 - cut, 0.001), 0.0, 1.0);
    return spow(angular, power);
}

// orbGlassLiquidAnim, con il vetro acceso. `uv01` ha la y verso il basso, come `position` di SwiftUI.
float4 glassLiquid(float2 uv01, U u) {
    float2 size = float2(u.f(SIZE_X), u.f(SIZE_Y));
    float2 fc = float2(uv01.x, 1.0 - uv01.y) * size;
    float2 uv = (2.0 * fc - size) / max(min(size.x, size.y), 1.0);

    float rad = max(u.f(RADIUS), 0.05);
    float t = u.f(TIME) * u.f(SPEED);
    float soft = u.f(EDGE_SOFT);
    float contourRad = rad * contourScale(uv, t, u.f(CONTOUR));

    // Fuori dalla sfera: solo l'alone (nero a Glow 0).
    if (length(uv) > contourRad * (1.01 + edgeD(soft))) {
        float3 halo = clamp(edgeGlow(float3(0.0), uv, contourRad, soft, u.f(EDGE_GLOW), u.c(GLOW_C)), 0.0, 1.0);
        return float4(halo, max(halo.r, max(halo.g, halo.b)));
    }

    float2 p = uv / contourRad;
    float pd = length(p);
    float clearFa = 1.0 - smoothstep(0.995, 1.04, pd);
    float2 normal = contourNormal(uv, rad, t, u.f(CONTOUR));
    float edgeDepth = max(1.0 - pd, 0.0);
    float refractionWidth = 0.015 + 0.95 * clamp(u.f(SHELL_MID_A), 0.0, 1.0);
    float profile = spow(refractionProfile(edgeDepth / max(refractionWidth, 0.001)), 0.68);
    float glassOpacity = clamp(u.f(GLASS_OPACITY), 0.0, 1.0);
    float2 refractedP = p - normal * (1.6 * glassOpacity * profile);

    float3 fcol = float3(0.0);
    if (clearFa > 0.0) {
        // Dispersione: tre campioni solo se c'è separazione dei canali (Gloss > 0).
        float split = 0.14 * clamp(u.f(GLOSS), 0.0, 2.0) * glassOpacity * profile;
        if (split > 0.0) {
            fcol = float3(voiceWave(refractedP - normal * split, t, u).r,
                          voiceWave(refractedP, t, u).g,
                          voiceWave(refractedP + normal * split, t, u).b);
        } else {
            fcol = voiceWave(refractedP, t, u);
        }
    }

    float lum = dot(fcol, float3(0.213, 0.715, 0.072));
    float3 clearSat = clamp(float3(lum) + (fcol - float3(lum)) * 1.22, 0.0, 1.0);
    float3 col = over(u.c(CANVAS), clearSat, 0.99 * clearFa);

    // Luce di superficie su un arco sottile: il cambio vero lo fa il fluido rifratto.
    float shellEdgeA = clamp(u.f(SHELL_EDGE_A), 0.0, 1.0);
    float surfaceWidth = 0.026 + 0.055 * shellEdgeA;
    float surfaceBand = (1.0 - smoothstep(0.0, surfaceWidth, edgeDepth)) * clearFa;
    float opticalRim = spow(surfaceBand, 1.8);
    col = over(col, u.c(SHELL_INNER), opticalRim * u.f(GLASS_OPACITY) * 0.45);

    float coolSplit = highlightLobe(normal, normalize(float2(0.84, 0.54)), -0.32, 1.8);
    float warmSplit = highlightLobe(normal, normalize(float2(-0.62, -0.78)), -0.28, 2.0);
    float dispersion = opticalRim * clamp(u.f(GLOSS), 0.0, 2.0) * (0.8 + 0.8 * u.f(SHELL_EDGE_A));
    col = over(col, u.c(SHELL_MID), dispersion * coolSplit);
    col = over(col, u.c(SHELL_EDGE), dispersion * warmSplit);

    float edgeShadow = opticalRim * (0.015 + 0.15 * u.f(SHELL_EDGE_A))
                     * (0.15 + 0.85 * max(dot(normal, float2(0.45, -0.89)), 0.0));
    col *= 1.0 - edgeShadow;

    float sheen = clamp(u.f(SHEEN), 0.0, 2.0);
    float key = opticalRim * highlightLobe(normal, normalize(float2(-0.68, 0.73)), 0.2, 2.8) * sheen * 1.4;
    float fill = opticalRim * highlightLobe(normal, normalize(float2(0.74, -0.67)), 0.4, 3.6) * sheen;
    col = over(col, u.c(SHEEN_C), key);
    col = over(col, u.c(SPEC_C), fill);

    // Bordo della sfera: fuori tutto a zero, così si vede lo sfondo della pagina.
    float ballA = 1.0 - smoothstep(0.99 - edgeD(soft), 1.01 + edgeD(soft), pd);
    col = clamp(col * max(u.f(EXPOSURE), 0.0), 0.0, 1.0) * ballA;
    float3 finalColor = clamp(edgeGlow(col, uv, contourRad, soft, u.f(EDGE_GLOW), u.c(GLOW_C)), 0.0, 1.0);
    float emissionAlpha = max(finalColor.r, max(finalColor.g, finalColor.b));
    return float4(finalColor, clamp(max(ballA, emissionAlpha), 0.0, 1.0));
}

} // namespace orb

/// `colorEffect` di SwiftUI: colore premoltiplicato, come il `fs_main` dell'HTML (blend "one, one-minus-src-alpha").
[[ stitchable ]] half4 ariaOrb(float2 position, half4 color, float2 size, device const float *values, int count) {
    if (count < 88 || size.x < 1.0 || size.y < 1.0) { return half4(0.0); }
    orb::U u = { values };
    float2 uv01 = position / size;
    float4 c = orb::glassLiquid(uv01, u);

    // Il fit di fs_main: l'alone sfuma prima dei bordi del riquadro invece di essere tagliato.
    float rad = max(u.f(orb::RADIUS), 0.05);
    float t = u.f(orb::TIME) * u.f(orb::SPEED);
    float2 fc = float2(uv01.x, 1.0 - uv01.y) * size;
    float2 uv = (2.0 * fc - size) / max(min(size.x, size.y), 1.0);
    float contourRad = rad * orb::contourScale(uv, t, u.f(orb::CONTOUR));
    float2 q = (2.0 * fc - size) / size;
    float fitFeather = 2.0 / max(min(size.x, size.y), 1.0);
    float fitStart = min(mix(contourRad, 1.0, 0.5), 1.0 - fitFeather);
    float fit = 1.0 - smoothstep(fitStart, 1.0, max(abs(q.x), abs(q.y)));
    return half4(c * fit);
}
