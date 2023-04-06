#version 330 core

uniform vec3 RayOrigin;
uniform vec3 ForwardDir;
uniform float FOV;
uniform int Bounces;

const vec3 skyColor = vec3(0.2, 0.2, 0.4);

in vec2 Resolution;

out vec4 fragColor;

struct sphere {
	vec3 position;
	vec3 albedo;
	float radius;
	bool null;
};

struct hitPayload {
	float hitDistance;
	vec3 worldPosition;
	vec3 worldNormal;

	int objectIndex;
};

sphere spheres[3];

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
	for (int i = 0; i < 3; i++) {
		// (bx^2 + by^2)t^2 + 2(axbx + ayby)t + (ax^2 + ay^2 - r^2) = 0

		// a = ray origin
		// b = ray direction
		// r = radius of circle
		// t = hit distance

		vec3 origin = rayOrigin - spheres[i].position;

		float a = dot(rayDir, rayDir);
		float b = 2.0 * dot(origin, rayDir);
		float c = dot(origin, origin) - spheres[i].radius * spheres[i].radius;

		// b^2 - 4ac
		float discriminant = b * b - 4.0 * a * c;
		if (discriminant < 0.0) {
			continue;
		}

		// (-b +- sqrt(discriminant)) / 2a
		float closestT = (-b - sqrt(discriminant)) / (2.0 * a);
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

void main() {
	vec2 uv = gl_FragCoord.xy / Resolution.xy * 2.0 - 1.0;
	vec4 target = inverseProjection(FOV, 0.1, 100.0) * vec4(uv.xy, 1.0, 1.0);
	vec3 rayDir = vec3(inverseView(RayOrigin, ForwardDir) * vec4(normalize(vec3(target) / target.w), 0.0));
	vec3 rayOrigin = RayOrigin;
	
	// initiazlize spheres
	spheres[0].position = vec3(0.0);
	spheres[0].albedo = vec3(0.7);
	spheres[0].radius = 0.5;
	spheres[0].null = false;

	spheres[1].position = vec3(-0.5, 0.0, -1.0);
	spheres[1].albedo = vec3(0.2, 0.2, 1.0);
	spheres[1].radius = 0.2;
	spheres[1].null = false;

	spheres[2].position = vec3(0.5, 0.0, -2.0);
	spheres[2].albedo = vec3(1.0, 0.2, 0.2);
	spheres[2].radius = 1;
	spheres[2].null = false;
	
	vec3 color = vec3(0.0);
	float multiplier = 1.0;
	for (int i = 0; i < Bounces; i++) {
		hitPayload payload = traceRay(rayDir, rayOrigin);
		if (payload.hitDistance < 0) {
			color += skyColor * multiplier;
			break;
		}

		vec3 lightDir = vec3(-0.1, -1.0, -1.0);
		lightDir = normalize(lightDir);

		float lightIntensity = max(0, dot(payload.worldNormal, -lightDir));

		vec3 sphereColor = spheres[payload.objectIndex].albedo;
		sphereColor *= lightIntensity;
		color += sphereColor * multiplier;

		multiplier *= 0.7;

		rayOrigin = payload.worldPosition + payload.worldNormal * 0.0001;
		rayDir = reflect(rayDir, payload.worldNormal);
	}

	fragColor = vec4(color, 1.0);
}