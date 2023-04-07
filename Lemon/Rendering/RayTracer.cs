using ImGuiNET;
using OpenTK.Graphics.OpenGL4;
using OpenTK.Mathematics;
using OpenTK.Windowing.Common;
using OpenTK.Windowing.GraphicsLibraryFramework;

namespace Lemon.Rendering;

internal sealed class RayTracer : IDisposable {
    public RayTracer(string vertCode, string fragCode, float width, float height) {
        int vertShaderHandle = GL.CreateShader(ShaderType.VertexShader);
        GL.ShaderSource(vertShaderHandle, vertCode);
        GL.CompileShader(vertShaderHandle);

        string vertShaderInfoLog = GL.GetShaderInfoLog(vertShaderHandle);
        if (vertShaderInfoLog != string.Empty) {
            Console.WriteLine(vertShaderInfoLog);
        }

        int fragShaderHandle = GL.CreateShader(ShaderType.FragmentShader);
        GL.ShaderSource(fragShaderHandle, fragCode);
        GL.CompileShader(fragShaderHandle);

        string fragShaderInfoLog = GL.GetShaderInfoLog(fragShaderHandle);
        if (fragShaderInfoLog != string.Empty) {
            Console.WriteLine(fragShaderInfoLog);
        }

        GL.UseProgram(0);
        Handle = GL.CreateProgram();

        GL.AttachShader(Handle, vertShaderHandle);
        GL.AttachShader(Handle, fragShaderHandle);
        GL.LinkProgram(Handle);

        GL.DetachShader(Handle, vertShaderHandle);
        GL.DetachShader(Handle, fragShaderHandle);

        GL.DeleteShader(vertShaderHandle);
        GL.DeleteShader(fragShaderHandle);

        GL.UseProgram(Handle);

        int viewportLocation = GL.GetUniformLocation(Handle, "ViewportSize");
        GL.Uniform2(viewportLocation, width, height);

        camera = new Camera(60f, 0.1f, 100f);

        rayOriginUniformLocation = GL.GetUniformLocation(Handle, "RayOrigin");
        GL.Uniform3(rayOriginUniformLocation, camera.Position);

        forwardDirUniformLocation = GL.GetUniformLocation(Handle, "ForwardDir");
        GL.Uniform3(forwardDirUniformLocation, camera.ForwardDirection);

        fovUniformLocation = GL.GetUniformLocation(Handle, "FOV");
        GL.Uniform1(fovUniformLocation, camera.Fov);

        bouncesUniformLocation = GL.GetUniformLocation(Handle, "Bounces");
        GL.Uniform1(bouncesUniformLocation, bounces);

        timeUniformLocation = GL.GetUniformLocation(Handle, "time");
        GL.Uniform1(timeUniformLocation, time);

        Info = string.Empty;
    }

    public int Handle { get; init; }
    public string Info { get; private set; }
    public int FrameCount { get; set; } = 0;

    private readonly Camera camera;
    private int bounces = 16;
    private float time = 0f;

    private readonly int rayOriginUniformLocation, forwardDirUniformLocation;
    private readonly int fovUniformLocation, bouncesUniformLocation, timeUniformLocation;

    private bool disposed = false;

    public void OnUpdate(float deltaTime, MouseState mouseState, KeyboardState keyboardState, out CursorState cursorState) {
        if (!keyboardState.IsKeyDown(Keys.Tab)) time += deltaTime;

        if (camera.OnUpdate(deltaTime, mouseState, keyboardState, out cursorState)) // if the camera moved
            FrameCount = 0;

        if (keyboardState.IsKeyReleased(Keys.R))
            bounces--;
        else if (keyboardState.IsKeyReleased(Keys.T))
            bounces++;

        bounces = Math.Max(1, bounces);

        GL.Uniform3(rayOriginUniformLocation, camera.Position);
        GL.Uniform3(forwardDirUniformLocation, camera.ForwardDirection);
        GL.Uniform1(fovUniformLocation, camera.Fov);
        GL.Uniform1(bouncesUniformLocation, bounces);
        GL.Uniform1(timeUniformLocation, time);

        Info = $"Bounces: {bounces}, ForwardDir: {camera.ForwardDirection}";
    }

    ~RayTracer() {
        Dispose();
    }

    public void Dispose() {
        if (disposed) return;

        GL.UseProgram(0);
        GL.DeleteProgram(Handle);

        disposed = true;
        GC.SuppressFinalize(this);
    }
}
