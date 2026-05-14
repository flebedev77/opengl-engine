#version 300 es

precision highp float;

uniform vec2 uResolution;
uniform float uTime;

out vec4 outColor;

float rand(vec2 p) {
    return fract(sin(dot(p.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

uint pcg_hash(uint i) {
    uint state = i * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float better_rand(vec2 p) {
	return fract(float(
		pcg_hash(uint(p.x + p.y))
	));
}


vec2 rand_vec(vec2 p) {
	return (vec2(
		rand(p) * 2.0 - 1.0, 
		rand(p + vec2(1, 2343)) * 2.0 - 1.0
	));
}

float lerp(float a, float b, float t) {
	return a + (b-a) * t;
}

float noise2d(vec2 p) {
	vec2 br = ceil(p);
	vec2 bl = br - vec2(1, 0);
	vec2 tl = bl + vec2(0, 1);
	vec2 tr = tl + vec2(1, 0);
	
	float brn = rand(br);
	float bln = rand(bl);
	float tln = rand(tl);
	float trn = rand(tr);
	
	float bn = lerp(bln, brn, fract(p.x));
	float tn = lerp(tln, trn, fract(p.x));
	
	float v = lerp(bn, tn, fract(p.y));
	return v;
}

float mapv(float v, float fmin, float fmax, float tmin, float tmax) {
	return (v-fmin) / (fmax-fmin) * (tmax-tmin) + tmin;
}

float perlin2d(vec2 p) {
	vec2 f = fract(p);
	vec2 br = ceil(p);
	vec2 bl = br - vec2(1, 0);
	vec2 tl = bl + vec2(0, 1);
	vec2 tr = tl + vec2(1, 0);
	
	vec2 brn = rand_vec(br);
	vec2 bln = rand_vec(bl);
	vec2 tln = rand_vec(tl);
	vec2 trn = rand_vec(tr);
	
	float brv = dot(brn, (p - br));
	float blv = dot(bln, (p - bl));
	float trv = dot(trn, (p - tr));
	float tlv = dot(tln, (p - tl));
	
	float bn = lerp(blv, brv, f.x);
	float tn = lerp(tlv, trv, f.x);
	
	float v = lerp(bn, tn, f.y);
	return v * 0.5 + 0.5;
}

void main()
{
    vec2 uv = gl_FragCoord.xy * 0.001;///uResolution;
    outColor = vec4(perlin2d(uv*20.0));
    outColor += vec4(perlin2d(uv*60.0) * 0.2);
}
