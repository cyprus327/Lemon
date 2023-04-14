#version 330 core

uniform vec3 RayOrigin;
uniform vec3 ForwardDir;
uniform float Time;
uniform int Samples;
uniform int Bounces;
uniform float FOV;
uniform vec2 Mouse;

float rngState;

const int NUM_SPHERES = 5;
const float PI = 3.14159265359;
const float PI2 = 6.28318530717;
const float GAMMA = 2.2;

in vec2 Resolution;

out vec4 fragColor;

/* "unexpected '{'"
enum MaterialType {
    DIELECTRIC,
    METAL,
    LAMBERTIAN
}; */

const int DIELECTRIC = 0;
const int METAL = 1;
const int LAMBERTIAN = 2;

struct hitInfo {
	float hitDist;
	vec3 worldPos;
	vec3 worldNormal;

    int objectInd;
};

struct material {
	int type;
    vec3 albedo;
    float parameter;
};
    
struct sphere {
	vec3 pos;
    float radius;
    material mat;
};
    
struct ray {
    vec3 origin;
    vec3 dir;
};
    
sphere spheres[NUM_SPHERES];

mat4 lookAt(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    mat4 viewMat = mat4(1.0);
    viewMat[0][0] = s.x;
    viewMat[1][0] = s.y;
    viewMat[2][0] = s.z;
    viewMat[0][1] = u.x;
    viewMat[1][1] = u.y;
    viewMat[2][1] = u.z;
    viewMat[0][2] = -f.x;
    viewMat[1][2] = -f.y;
    viewMat[2][2] = -f.z;
    viewMat[3][0] = -dot(s, eye);
    viewMat[3][1] = -dot(u, eye);
    viewMat[3][2] = dot(f, eye);
    return viewMat;
}

mat4 inverseProjection(float fov, float nearClip, float farClip) {
    mat4 projectionMat = mat4(0.0);
	float aspect = Resolution.x / Resolution.y;
	float f = 1.0 / tan(radians(0.5 * FOV));
	float nf = 1.0 / (nearClip - farClip);
	projectionMat[0][0] = f / aspect;
	projectionMat[1][1] = f;
	projectionMat[2][2] = (nearClip + farClip) * nf;
	projectionMat[2][3] = -1.0;
	projectionMat[3][2] = 2.0 * nearClip * farClip * nf;
    return inverse(projectionMat);
}

mat4 inverseView(vec3 pos, vec3 forwardDir) {
    mat4 viewMat = lookAt(pos, pos + forwardDir, vec3(0.0, 1.0, 0.0));
    return inverse(viewMat);
}

// pseudorandom generation from https://stackoverflow.com/users/2434130/spatial
uint hash(uint x) {
    x += (x << 10u);
    x ^= (x >>  6u);
    x += (x <<  3u);
    x ^= (x >> 11u);
    x += (x << 15u);
    return x;
}

uint hash(uvec2 v) { return hash(v.x ^ hash(v.y)                        ); }
uint hash(uvec3 v) { return hash(v.x ^ hash(v.y) ^ hash(v.z)            ); }
uint hash(uvec4 v) { return hash(v.x ^ hash(v.y) ^ hash(v.z) ^ hash(v.w)); }

float floatConstruct(uint m) {
	//   binary32 mantissa bitmask
    m &= 0x007FFFFFu;  // keep only mantissa bits
	//   1.0 in IEEE binary32
    m |= 0x3F800000u;  // add fractional part to 1.0

	// 0 to 1 range
    return uintBitsToFloat(m) - 1.0;       
}

float random(float x) { return floatConstruct(hash(floatBitsToUint(x))); }
float random(vec2  v) { return floatConstruct(hash(floatBitsToUint(v))); }
float random(vec3  v) { return floatConstruct(hash(floatBitsToUint(v))); }
float random(vec4  v) { return floatConstruct(hash(floatBitsToUint(v))); }

float random() {
    return random(vec3(gl_FragCoord.xy * rngState, rngState++));
}

vec3 randomUnitVector() {
	float theta = random() * PI2;
    float z = random() * 2.0 - 1.0;
    float a = sqrt(1.0 - z * z);
    vec3 vector = vec3(a * cos(theta), a * sin(theta), z);
    return vector * sqrt(random());
}

float approximateLight(float c, float i) {
    // r(theta) = r0 + (1 - r0) * (1 - cos(theta))^5
 	float r0 = (1.0 - i) / (1.0 + i);
    r0 *= r0;
    return r0 + (1.0 - r0) * pow(1.0 - c, 5.0);
}

hitInfo hitSphere(ray r) {
    bool hitAnything = false;
    hitInfo info;
    info.hitDist = 1e38;
    
    for (int i = 0; i < NUM_SPHERES; i++) {
     	sphere sph = spheres[i];
        
        vec3 oc = r.origin - sph.pos;
        float a = dot(r.dir, r.dir);
        float b = dot(oc, r.dir);
        float c = dot(oc, oc) - sph.radius * sph.radius;
        float discriminant = b * b - a * c;
        
        if (discriminant < 0.0) {
            continue;
        }

		float t = (-b - sqrt(discriminant)) / a;
        if (t >= 0.0 && t < info.hitDist) {
            info.hitDist = t;
            hitAnything = true;
                
            info.worldPos = sph.pos + oc + r.dir * t;
            info.worldNormal = (info.worldPos - sph.pos) / sph.radius;
            info.objectInd = i;
        }
    }
    
    if (hitAnything) {
        return info;
    }
    
    info.hitDist = -1.0;
 	return info;
}

vec3 traceRay(ray r) {
    vec3 color = vec3(0.0);
    vec3 mask = vec3(1.0);
        
    for (int b = 0; b < Bounces; b++) {
        hitInfo info = hitSphere(r);
        if (info.hitDist >= 0.001) {
            material mat = spheres[info.objectInd].mat;

            if (mat.type == LAMBERTIAN) {
                vec3 direction = info.worldNormal + randomUnitVector();
                r = ray(info.worldPos, direction);
                color *= mat.albedo * mask;
                mask *= mat.albedo;
            }
            else if (mat.type == METAL) {
                vec3 reflected = reflect(r.dir, info.worldNormal);
                vec3 dir = randomUnitVector() * mat.parameter + reflected;
                
                if (dot(dir, info.worldNormal) > 0.0) {
                    r = ray(info.worldPos, dir);
                    color *= mat.albedo * mask;
                    mask *= mat.albedo;
                }
            }
            else if (mat.type == DIELECTRIC) {                
                vec3 outwardNormal;
                float eta, cosine;
                
                float dt = dot(r.dir, info.worldNormal);
                
                if (dt > 0.0) {
		            outwardNormal = -info.worldNormal;
                    eta = mat.parameter;
                    cosine = eta * dt / length(r.dir);
                }
                else {
                    outwardNormal = info.worldNormal;
                    eta = 1.0 / mat.parameter;
                    cosine = -dt / length(r.dir);
                }

                if (random() < approximateLight(cosine, mat.parameter)) {
                    vec3 reflected = reflect(r.dir, info.worldNormal);
                    r = ray(info.worldPos, reflected);
                }
                else {
                    vec3 refracted = refract(normalize(r.dir), normalize(outwardNormal), eta);
                    r = ray(info.worldPos, refracted);
                }
                
                color *= mask;
            }
        }
        else {
            vec3 skyColor = vec3(0.6, 0.6, 0.8);
            skyColor = pow(skyColor, vec3(GAMMA));
            color = mask * skyColor;
        }
    }
        
 	return color;
}

void main() {
    spheres[0] = sphere(vec3(0, 1, 0), 1.0, material(LAMBERTIAN, vec3(0.6, 0.1, 0.05), 0.0));
    spheres[1] = sphere(vec3(0, 1, 2.5), 1.0, material(METAL, vec3(0.9, 0.9, 0.9), 0.01));
    spheres[2] = sphere(vec3(0, 1, -2.5), 1.0, material(DIELECTRIC, vec3(0, 0, 0), 1.5));
    spheres[3] = sphere(vec3(0, 1, -2.5), -0.92, material(DIELECTRIC, vec3(0.9, 0.9, 0.9), 1.5));
    spheres[4] = sphere(vec3(0, -1e3, 0), 1e3, material(METAL, vec3(0.7, 0.75, 0.8), 0.4));
    
    rngState = Time;
    
    vec2 uv = gl_FragCoord.xy / Resolution.xy * 2.0 - 1.0;
    vec2 pixelSize = vec2(1.0) / Resolution.xy;
    
    float ratio = Resolution.x / Resolution.y;
    
    
    float halfWidth = tan(radians(FOV) * 0.5);
    float halfHeight = halfWidth / ratio;
    
    // camera vectors
    const float dist = 6.5;
    vec2 mousePos = Mouse / Resolution.xy;  
    if (all(equal(mousePos, vec2(0.0)))) {
        mousePos = vec2(0.55, 0.2);
    }
    
    float x = cos(mousePos.x * 10.0) * dist;
    float z = sin(mousePos.x * 10.0) * dist;
    float y = mousePos.y * 10.0;
        
    vec3 origin = vec3(x, y, z);
    vec3 lookAt = vec3(0.0, 1.0, 0.0);
    vec3 upVector = vec3(0.0, 1.0, 0.0);
    
    vec3 w = normalize(origin - lookAt);
    vec3 u = cross(upVector, w);
    vec3 v = cross(w, u);
        
    vec3 lowerLeft = origin - halfWidth * u - halfHeight * v - w;
    vec3 horizontal = u * halfWidth * 2.0;
    vec3 vertical = v * halfHeight * 2.0;
    
    ray r = ray(origin, vec3(0.0));
    vec3 color = vec3(0.0);

    for (int s = 0; s < Samples; s++) {        
     	r.dir = lowerLeft - origin; 
        r.dir += horizontal * (pixelSize.x * random() + uv.x);
        r.dir += vertical * (pixelSize.y * random() + uv.y);
        color += traceRay(r);
    }
    
    color /= float(Samples);
    
    // gamma correct
    color = pow(color, vec3(1.0 / GAMMA));

    fragColor = vec4(color, 1.0);
}