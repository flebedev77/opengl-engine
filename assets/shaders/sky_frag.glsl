#version 330 core
in vec3 frag_pos;
in vec3 frag_normal;

out vec4 frag_color;

uniform vec3 light_pos;
uniform vec3 camera_pos;

// Noise functions
const mat2 myt = mat2(.12121212, .13131313, -.13131313, .12121212);
const vec2 mys = vec2(1e4, 1e6);

vec2 rhash(vec2 uv) {
  uv *= myt;
  uv *= mys;
  return fract(fract(uv / mys) * uv);
}

vec3 hash(vec3 p) {
  return fract(
      sin(vec3(dot(p, vec3(1.0, 57.0, 113.0)), dot(p, vec3(57.0, 113.0, 1.0)),
               dot(p, vec3(113.0, 1.0, 57.0)))) *
      43758.5453);
}

vec3 voronoi3d(const in vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);

  float id = 0.0;
  vec2 res = vec2(100.0);
  for (int k = -1; k <= 1; k++) {
    for (int j = -1; j <= 1; j++) {
      for (int i = -1; i <= 1; i++) {
        vec3 b = vec3(float(i), float(j), float(k));
        vec3 r = vec3(b) - f + hash(p + b);
        float d = dot(r, r);

        float cond = max(sign(res.x - d), 0.0);
        float nCond = 1.0 - cond;

        float cond2 = nCond * max(sign(res.y - d), 0.0);
        float nCond2 = 1.0 - cond2;

        id = (dot(p + b, vec3(1.0, 57.0, 113.0)) * cond) + (id * nCond);
        res = vec2(d, res.x) * cond + res * nCond;

        res.y = cond2 * d + nCond2 * res.y;
      }
    }
  }

  return vec3(sqrt(res), abs(id));
}

float rand(float n){return fract(sin(n) * 43758.5453123);}
float id(vec3 v) {return v.x + v.y + v.z;}

float noise(float p){
	float fl = floor(p);
  float fc = fract(p);
	return mix(rand(fl), rand(fl + 1.0), fc);
}

float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float noise3(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}

void main() {
  // frag_color = vec4(frag_normal, 1.0);
  // Night stars
  // float v = smoothstep(0.9, 0.97, 1 - voronoi3d(frag_normal * 30).r);
  // vec3 out_color = vec3(0.9, 0.9, 1) * v;
  // out_color += vec3(0.357, 0.047, 0.478) * noise3(frag_normal * 2) * 0.01;

  // Day sky

  //Sun
  float y_factor = -frag_normal.y;
  vec3 high_color = vec3(0.5, 0.5, 0.9);
  vec3 out_color = mix(vec3(0.5, 0.5, 0.7), high_color, y_factor);
  vec3 view_dir = normalize(frag_pos - camera_pos);
  vec3 light_dir = normalize(light_pos);

  float sun_factor = clamp((pow(max(dot(view_dir, light_dir) - 0.002, 0), 100)) * 2.0, 0, 1);
  out_color = mix(out_color, vec3(1, 1, 0.8), sun_factor);

  frag_color = vec4(out_color, 1.0);
}
