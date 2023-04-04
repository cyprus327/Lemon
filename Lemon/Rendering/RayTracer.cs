using OpenTK.Graphics.OpenGL4;
using OpenTK.Mathematics;
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

        rayOriginUniformLocation = GL.GetUniformLocation(Handle, "RayOrigin");
        GL.Uniform3(rayOriginUniformLocation, rayOrigin);

    }

    public int Handle { get; init; }
    public string Info { get; set; }

    private Vector3 rayOrigin = new Vector3(0f, 0f, 1.5f);
    private Vector3 rayDir = new Vector3(0f, 0f, -1f);

    private int rayOriginUniformLocation;

    private bool disposed = false;

    public void OnUpdate(float deltaTime, KeyboardState keyboardState) {
        float speed = 5;

        if (keyboardState.IsKeyDown(Keys.W))
            rayOrigin.Z -= deltaTime / speed;
        else if (keyboardState.IsKeyDown(Keys.S))
            rayOrigin.Z += deltaTime / speed;
        if (keyboardState.IsKeyDown(Keys.A))
            rayOrigin.X -= deltaTime / speed;
        else if (keyboardState.IsKeyDown(Keys.D))
            rayOrigin.X += deltaTime / speed;
        if (keyboardState.IsKeyDown(Keys.Q))
            rayOrigin.Y -= deltaTime / speed;
        else if (keyboardState.IsKeyDown(Keys.E))
            rayOrigin.Y += deltaTime / speed;

        GL.Uniform3(rayOriginUniformLocation, rayOrigin);
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
