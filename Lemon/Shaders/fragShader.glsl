#version 330 core

uniform vec3 RayOrigin;
uniform vec3 ForwardDir;
uniform float FOV;
uniform int Bounces;
uniform int Samples;
uniform float Time;

const int STRATA = 3;
const float PI = 3.14159265;
const vec3 SKY_COLOR = vec3(0.7, 0.7, 1.0);
const int NUM_SPHERES = 4;
const float GAMMA = 1.2;

in vec2 Resolution;

out vec4 fragColor;

struct material {
	vec3 albedo;
	float roughness;
	float metallic;
	float specular;
	float ambient;
};

struct sphere {
	vec3 position;
	float radius;

	int materialIndex;
};

struct hitPayload {
	float hitDistance;
	vec3 worldPosition;
	vec3 worldNormal;

	int objectIndex;
};

sphere spheres[NUM_SPHERES];
material materials[4];

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


hitPayload miss(vec3 rayDir) {
	hitPayload payload;
	payload.hitDistance = -1.0;
	return payload;
}

hitPayload closestHit(vec3 rayDir, vec3 rayOrigin, float hitDist, int objectIndex) {
	hitPayload payload;
	payload.hitDistance = hitDist;
	payload.objectIndex = objectIndex;

	vec3 origin = rayOrigin - spheres[objectIndex].position;
	payload.worldPosition = origin + rayDir * hitDist;
	payload.worldNormal = normalize(payload.worldPosition);

	payload.worldPosition += spheres[objectIndex].position;

	return payload;
}

hitPayload traceRay(vec3 rayDir, vec3 rayOrigin) {
	int closestSphere = -1;
	float hitDist = 1e38;
	for (int i = 0; i < NUM_SPHERES; i++) {
		// (bx^2 + by^2)t^2 + 2(axbx + ayby)t + (ax^2 + ay^2 - r^2) = 0

		// a = ray origin
		// b = ray direction
		// r = radius of circle
		// t = hit distance

		vec3 origin = rayOrigin - spheres[i].position;

		float a = dot(rayDir, rayDir);
		float b = dot(origin, rayDir);
		float c = dot(origin, origin) - spheres[i].radius * spheres[i].radius;

		// b^2 - 4ac
		float discriminant = b * b - a * c;
		if (discriminant < 0.0) {
			continue;
		}

		// (-b +- sqrt(discriminant)) / 2a
		float closestT = (-b - sqrt(discriminant)) / a;
		if (closestT < 0.0) continue;
		if (closestT < hitDist) {
			closestSphere = i;
			hitDist = closestT;
		}
	}

	if (closestSphere == -1) {
		return miss(rayDir);
	}

	return closestHit(rayDir, rayOrigin, hitDist, closestSphere);
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

void main() {
	vec2 uv = gl_FragCoord.xy / Resolution.xy * 2.0 - 1.0;
	vec4 target = inverseProjection(FOV, 0.1, 100.0) * vec4(uv.xy, 1.0, 1.0);
	vec3 rayDir = vec3(inverseView(RayOrigin, ForwardDir) * vec4(normalize(vec3(target) / target.w), 0.0));
	vec3 rayOrigin = RayOrigin;

	spheres[0].position = vec3(0.0, -1001.0, 0.0);
	spheres[0].radius = 1000.0;
	spheres[0].materialIndex = 0;
	materials[0].albedo = vec3(0.8, 0.8, 0.8);
	materials[0].roughness = 0.01;
	materials[0].metallic = 1.0;
	materials[0].specular = 0.01;
	materials[0].ambient = 0.1;
	
	spheres[1].position = vec3(-0.8, -0.2, 0.0);
	spheres[1].radius = 0.6;
	spheres[1].materialIndex = 1;
	materials[1].albedo = vec3(0.2, 0.2, 0.8);
	materials[1].roughness = 0.1;
	materials[1].metallic = 0.5;
	materials[1].specular = 0.1;
	materials[1].ambient = 0.1;

	spheres[2].position = vec3(0.6, -0.1, 0.0);
	spheres[2].radius = 0.5;
	spheres[2].materialIndex = 2;
	materials[2].albedo = vec3(0.2, 0.8, 0.2);
	materials[2].roughness = 0.01;
	materials[2].metallic = 0.0;
	materials[2].specular = 1.0;
	materials[2].ambient = 0.1;
			  
	spheres[3].position = vec3(0.0, 1.0, -0.8);
	spheres[3].radius = 0.9;
	spheres[3].materialIndex = 3;
	materials[3].albedo = vec3(0.8, 0.2, 0.2);
	materials[3].roughness = 0.1;
	materials[3].metallic = 0.01;
	materials[3].specular = 0.55;
	materials[3].ambient = 0.1;
	
	// currently the only light source
	vec3 lightPos = vec3(2.0, 3.0, 4.0);
	vec3 lightColor = vec3(1.0, 1.0, 1.0);
	float lightRadius = 1.0;
	
	vec3 totalCol = vec3(0.0);

	for (int s = 0; s < Samples; s++) {
		vec3 sampleCol = vec3(0.0);

		for (int y = 0; y < STRATA; y++) {
			for (int x = 0; x < STRATA; x++) {
				// calculate stratum position
				float xOffset = float(x) / float(STRATA);
				float yOffset = float(y) / float(STRATA);
				vec2 stratumPos = gl_FragCoord.xy + vec2(xOffset, yOffset);
				
				// calcualte ray direction and origin
				rayDir = vec3(inverseView(rayOrigin, ForwardDir) * vec4(normalize(vec3(target) / target.w), 0.0));
				rayOrigin = RayOrigin;

				// trace the ray
				float multiplier = 1.0;
				for (int i = 0; i < Bounces; i++) {
					hitPayload payload = traceRay(rayDir, rayOrigin);
					if (payload.hitDistance < 0.0) {
						sampleCol += SKY_COLOR * multiplier;
						break;
					}

					// calculate lighting and material
					material mat = materials[spheres[payload.objectIndex].materialIndex];
					
					vec3 toLight = lightPos - payload.worldPosition;
					float dist = length(toLight);
					vec3 lightDir = toLight / dist;
					float attenuation = 1.0 / (1.0 + lightRadius * dist);

					float lightIntensity = max(0.0, dot(payload.worldNormal, lightDir));
					lightIntensity = attenuation * lightIntensity + mat.ambient;

					vec3 diffuse = mat.albedo * lightColor * lightIntensity;

					vec3 viewDir = -normalize(rayDir);
					vec3 reflectDir = reflect(-lightDir, payload.worldNormal);
					float specular = pow(max(dot(viewDir, reflectDir), 0.0), mat.specular);

					vec3 specularColor = mat.specular * lightColor * specular;

					vec3 sphereCol = diffuse + specularColor;
					sampleCol += sphereCol * multiplier;

					multiplier *= 0.5;

					vec3 rand = vec3(
						random(vec3(stratumPos.xy, Time + float(s) - float(i))),
						random(vec3(float(s) - Time, stratumPos.xy + float(i))),
						random(vec3(float(i) + stratumPos.yx, Time + float(s)))
					);
					rayOrigin = payload.worldPosition + payload.worldNormal * 0.0001;
					rayDir = reflect(rayDir, payload.worldNormal + mat.roughness * rand);
				}
			}
		}

		totalCol += sampleCol / float(STRATA * STRATA);
	}

	vec3 color = totalCol / float(Samples);

	// gamma correct
	color = pow(color, vec3(1.0 / GAMMA));

	fragColor = vec4(color, 1.0);
}