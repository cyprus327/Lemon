using OpenTK.Graphics.OpenGL4;
using OpenTK.Mathematics;
using OpenTK.Windowing.Common;
using OpenTK.Windowing.GraphicsLibraryFramework;
using System.Numerics;
using Quaternion = OpenTK.Mathematics.Quaternion;
using Vector3 = OpenTK.Mathematics.Vector3;
using Vector2 = OpenTK.Mathematics.Vector2;

namespace Lemon.Rendering;
internal sealed class Camera { // convert this into glsl to actually use it
    public Camera(float vFov, float nearClip, float farClip) {
        Fov = vFov;
        NearClip = nearClip;
        FarClip = farClip;

        ForwardDirection = new Vector3(0f, 0f, -1f);
        Position = new Vector3(0f, 0f, 3f);
    }

    public float Fov { get; init; }
    public float NearClip { get; init; }
    public float FarClip { get; init; }
    public Vector3 ForwardDirection { get; private set; }
    public Vector3 Position { get; private set; }
    public float RotationSpeed { get; set; } = 0.1f;

    public void OnUpdate(float deltaTime, MouseState mouseState, KeyboardState keyboardState, out CursorState cursorState) {
        Vector3 upDir = new Vector3(0f, 1f, 0f);
        Vector3 rightDir = Vector3.Cross(ForwardDirection, upDir);

        float speed = 5f;
        if (keyboardState.IsKeyDown(Keys.W)) {
            Position += ForwardDirection * speed * deltaTime;
        }
        else if (keyboardState.IsKeyDown(Keys.S)) {
            Position -= ForwardDirection * speed * deltaTime;
        }
        if (keyboardState.IsKeyDown(Keys.A)) {
            Position -= rightDir * speed * deltaTime;
        }
        else if (keyboardState.IsKeyDown(Keys.D)) {
            Position += rightDir * speed * deltaTime;
        }
        if (keyboardState.IsKeyDown(Keys.Q)) {
            Position -= upDir * speed * deltaTime;
        }
        else if (keyboardState.IsKeyDown(Keys.E)) {
            Position += upDir * speed * deltaTime;
        }

        if (!mouseState.IsButtonDown(MouseButton.Right)) {
            cursorState = CursorState.Normal;
            return;
        }

        cursorState = CursorState.Grabbed;

        Vector2 delta = mouseState.Delta;
        if (delta.X != 0f || delta.Y != 0f) {
            float pitchDelta = -delta.Y * RotationSpeed;
            float yawDelta = -delta.X * RotationSpeed;

            ForwardDirection = Rotate(ForwardDirection, pitchDelta, yawDelta);
        }
    }

    public float DegToRad(float deg) {
        return deg * MathF.PI / 180;
    }

    public static Vector3 Rotate(Vector3 vector, float pitchDelta, float yawDelta) {
        // Convert pitch and yaw deltas from pixels to radians
        float pitch = MathHelper.DegreesToRadians(pitchDelta);
        float yaw = MathHelper.DegreesToRadians(yawDelta);

        // Create quaternions to represent the pitch and yaw rotations
        Quaternion pitchRotation = Quaternion.FromAxisAngle(Vector3.UnitX, pitch);
        Quaternion yawRotation = Quaternion.FromAxisAngle(Vector3.UnitY, yaw);

        // Combine the pitch and yaw rotations into a single quaternion
        Quaternion rotation = pitchRotation * yawRotation;

        // Apply the quaternion rotation to the input vector and return the result
        return Vector3.Transform(vector, rotation);
    }
}
