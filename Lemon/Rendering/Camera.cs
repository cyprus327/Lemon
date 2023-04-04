using OpenTK.Graphics.OpenGL4;
using OpenTK.Mathematics;
using OpenTK.Windowing.Common;
using OpenTK.Windowing.GraphicsLibraryFramework;

namespace Lemon.Rendering;
internal sealed class Camera { // convert this into glsl to actually use it
    public Camera(float vFov, float nearClip, float farClip, int viewportWidth, int viewportHeight) {
        Fov = vFov;
        NearClip = nearClip;
        FarClip = farClip;
        ViewportWidth = viewportWidth;
        ViewportHeight = viewportHeight;

        ForwardDirection = new Vector3(0f, 0f, -1f);
        Position = new Vector3(0f, 0f, 3f);
    }

    public int ViewportWidth { get; private set; }
    public int ViewportHeight { get; private set; }
    public float Fov { get; init; }
    public float NearClip { get; init; }
    public float FarClip { get; init; }
    public Vector3 ForwardDirection { get; private set; }
    public Vector3 Position { get; private set; }
    public float RotationSpeed { get; set; } = 0.3f;
    public Matrix4 ViewMat { get; private set; }
    public Matrix4 InverseViewMat { get; private set; }
    public Matrix4 ProjectionMat { get; private set; }
    public Matrix4 InverseProjectionMat { get; private set; }
    public Vector3[] RayDirections { get; private set; }

    public void OnUpdate(float deltaTime, MouseState mouseState, KeyboardState keyboardState, out CursorState cursorState) {
        Vector3 upDir = new Vector3(0f, 1f, 0f);
        Vector3 rightDir = Vector3.Cross(ForwardDirection, upDir);

        float speed = 5f;
        bool moved = false;
        if (keyboardState.IsKeyDown(Keys.W)) {
            Position += ForwardDirection * speed * deltaTime;
            moved = true;
        }
        else if (keyboardState.IsKeyDown(Keys.S)) {
            Position -= ForwardDirection * speed * deltaTime;
            moved = true;
        }
        if (keyboardState.IsKeyDown(Keys.A)) {
            Position -= rightDir * speed * deltaTime;
            moved = true;
        }
        else if (keyboardState.IsKeyDown(Keys.D)) {
            Position += rightDir * speed * deltaTime;
            moved = true;
        }
        if (keyboardState.IsKeyDown(Keys.Q)) {
            Position -= upDir * speed * deltaTime;
            moved = true;
        }
        else if (keyboardState.IsKeyDown(Keys.E)) {
            Position += upDir * speed * deltaTime;
            moved = true;
        }

        if (!mouseState.IsButtonDown(MouseButton.Right)) {
            cursorState = CursorState.Normal;
            return;
        }

        cursorState = CursorState.Grabbed;

        Vector2 delta = mouseState.Delta;
        if (delta.X != 0f || delta.Y != 0f) {
            float pitchDelta = delta.Y * RotationSpeed;
            float yawDelta = delta.X * RotationSpeed;

            var pitchQuat = Quaternion.FromAxisAngle(rightDir, -pitchDelta);
            var yawQuat = Quaternion.FromAxisAngle(new Vector3(0.0f, 1.0f, 0.0f), - yawDelta); // upDir

            // equivalent of glm::cross
            var quat = Quaternion.Multiply(pitchQuat, yawQuat) - Quaternion.Multiply(yawQuat, pitchQuat);
            quat = Quaternion.Normalize(quat);

            ForwardDirection = Rotate(quat, ForwardDirection);

            moved = true;
        }

        if (moved) {
            RecalculateView();
            RecalculateRayDirections();
        }
    }

    public void OnResize(int newWidth, int newHeight) {
        if (newWidth == ViewportWidth || newHeight == ViewportHeight) return;

        ViewportWidth = newWidth;
        ViewportHeight = newHeight;

        RecalculateProjection();
        RecalculateRayDirections();
    }

    private void RecalculateView() {
        ViewMat = Matrix4.LookAt(Position, Position + ForwardDirection, new Vector3(0f, 1f, 0f));
        InverseViewMat = Matrix4.Invert(ViewMat);
    }

    private void RecalculateRayDirections() {
        RayDirections = new Vector3[ViewportWidth * ViewportHeight];

        for (int y = 0; y < ViewportHeight; y++) {
            for (int x = 0; x < ViewportWidth; x++) {
                Vector2 coord = new Vector2((float)x / (float)ViewportWidth, (float)y / (float)ViewportHeight);
                coord.X = coord.X * 2f - 1f;
                coord.Y = coord.Y * 2f - 1f;

                Vector4 target = InverseProjectionMat * new Vector4(coord.X, coord.Y, 1, 1);
                Vector3 rayDir = new Vector3(InverseViewMat * new Vector4(Vector3.Normalize(new Vector3(target) / target.W), 0)); // world space
                RayDirections[x + y * ViewportWidth] = rayDir;
            }
        }
    }

    public void RecalculateProjection() {
        ProjectionMat = Matrix4.CreatePerspectiveFieldOfView(DegToRad(Fov), ViewportWidth / ViewportHeight, NearClip, FarClip);
        InverseProjectionMat = Matrix4.Invert(ProjectionMat);
    }

    private static float DegToRad(float deg) {
        return deg * MathF.PI / 180;
    }

    private static Vector3 Rotate(Quaternion quat, Vector3 vec) {
        var conj = Quaternion.Conjugate(quat);
        var q = new Quaternion(vec.X, vec.Y, vec.Z, 0);
        q = Quaternion.Multiply(quat, q);
        q = Quaternion.Multiply(q, conj);
        return new Vector3(q.X, q.Y, q.Z);
    }
}
