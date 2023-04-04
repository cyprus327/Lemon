#version 330 core

uniform vec3 RayOrigin;

in vec2 Resolution;

out vec4 fragColor;

void main() {
	vec2 uv = gl_FragCoord.xy / Resolution.xy * 2.0 - 1.0;

	// (bx^2 + by^2)t^2 + 2(axbx + ayby)t + (ax^2 + ay^2 - r^2) = 0

	// a = ray origin
	// b = ray direction
	// r = radius of circle
	// t = hit distance

	vec3 rayDir = vec3(uv.xy, -1.0);
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