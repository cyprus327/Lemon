#version 330 core

uniform vec3 RayOrigin;
uniform vec3 ForwardDir;

in vec2 Resolution;

out vec4 fragColor;

mat4 lookAt(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    mat4 viewMat = mat4(1.0); // initialize the matrix to the identity matrix
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
    float aspect = Resolution.x / Resolution.y;
    float f = 1.0 / tan(radians(fov) / 2.0);
    float nf = 1.0 / (nearClip - farClip);
    mat4 projectionMat = mat4(f / aspect, 0.0, 0.0, 0.0,
                              0.0, f, 0.0, 0.0,
                              0.0, 0.0, (farClip + nearClip) * nf, -1.0,
                              0.0, 0.0, 2.0 * farClip * nearClip * nf, 0.0);
    return inverse(projectionMat);
}

mat4 inverseView(vec3 pos, vec3 forwardDir) {
    mat4 viewMat = lookAt(pos, pos + forwardDir, vec3(0.0, 1.0, 0.0));
    return inverse(viewMat);
}

void main() {
	vec2 uv = gl_FragCoord.xy / Resolution.xy * 2.0 - 1.0;

	// (bx^2 + by^2)t^2 + 2(axbx + ayby)t + (ax^2 + ay^2 - r^2) = 0

	// a = ray origin
	// b = ray direction
	// r = radius of circle
	// t = hit distance

	vec4 target = inverseProjection(60.0, 0.1, 100.0) * vec4(uv.xy, 1.0, 1.0);
	vec3 rayDir = vec3(inverseView(RayOrigin, ForwardDir) * vec4(normalize(vec3(target) / target.w), 0.0));
	rayDir = normalize(rayDir);
	float radius = 0.5;

	float a = dot(rayDir, rayDir);
	float b = 2.0 * dot(RayOrigin, rayDir);
	float c = dot(RayOrigin, RayOrigin) - radius * radius;

	// b^2 - 4ac
	float discriminant = b * b - 4.0 * a * c;
	if (discriminant < 0) {
		fragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	// (-b +- sqrt(discriminant)) / 2a
	float closestT = (-b - sqrt(discriminant)) / (2.0 * a);

	vec3 hitPoint = RayOrigin + rayDir * closestT;
	vec3 normal = normalize(hitPoint);

	vec3 lightDir = vec3(-1.0, -1.0, -1.0);
	lightDir = normalize(lightDir);

	float lightIntensity = max(0, dot(normal, -lightDir));

	vec3 sphereColor = vec3(1.0, 0.0, 0.0);
	sphereColor *= lightIntensity;
	fragColor = vec4(sphereColor, 1.0);
}