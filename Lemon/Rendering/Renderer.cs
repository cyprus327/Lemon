using OpenTK.Windowing.Desktop;
using OpenTK.Windowing.Common;
using OpenTK.Graphics.OpenGL4;
using ImGuiNET;
using Lemon.Shaders;

namespace Lemon.Rendering;

internal sealed class Renderer : GameWindow {
    public Renderer(int width, int height, string title) :
        base(
            GameWindowSettings.Default,
            new NativeWindowSettings() {
                Size = (width, height),
                Title = title,
                StartVisible = false,
                StartFocused = true,
            }
        ) {
        this.CenterWindow();
    }

    private Camera camera;
    private RayTracer rayTracer;
    private int vertexArrayHandle, vertexBufferHandle, indexBufferHandle;

    protected override void OnLoad() {
        base.OnLoad();

        this.IsVisible = true;

        float[] vertices = {
            0f, this.ClientSize.Y,                
            this.ClientSize.X, this.ClientSize.Y, 
            this.ClientSize.X, 0f,                
            0f, 0f                                
        };

        int[] indices = {                         
            0, 1, 2,
            0, 2, 3
        };

        vertexBufferHandle = GL.GenBuffer();
        GL.BindBuffer(BufferTarget.ArrayBuffer, vertexBufferHandle);
        GL.BufferData(BufferTarget.ArrayBuffer, vertices.Length * sizeof(float), vertices, BufferUsageHint.StaticDraw);
        GL.BindBuffer(BufferTarget.ArrayBuffer, 0);

        indexBufferHandle = GL.GenBuffer();
        GL.BindBuffer(BufferTarget.ElementArrayBuffer, indexBufferHandle);
        GL.BufferData(BufferTarget.ElementArrayBuffer, indices.Length * sizeof(int), indices, BufferUsageHint.StaticDraw);
        GL.BindBuffer(BufferTarget.ElementArrayBuffer, 0);

        vertexArrayHandle = GL.GenVertexArray();
        GL.BindVertexArray(vertexArrayHandle);

        GL.BindBuffer(BufferTarget.ArrayBuffer, vertexBufferHandle);
        GL.VertexAttribPointer(0, 2, VertexAttribPointerType.Float, false, 2 * sizeof(float), 0);
        GL.EnableVertexAttribArray(0);

        GL.BindVertexArray(0);

        string vertShaderCode = Reader.ReadToString("../../../Shaders/vertShader.glsl");
        string fragShaderCode = Reader.ReadToString("../../../Shaders/fragShader.glsl");
        rayTracer = new RayTracer(vertShaderCode, fragShaderCode, this.ClientSize.X, this.ClientSize.Y);

        camera = new Camera(60f, 0.1f, 100f, this.ClientSize.X, this.ClientSize.Y);
    }

    protected override void OnUnload() {
        base.OnUnload();

        GL.BindVertexArray(0);
        GL.DeleteVertexArray(vertexArrayHandle);

        GL.BindBuffer(BufferTarget.ElementArrayBuffer, 0);
        GL.DeleteBuffer(indexBufferHandle);

        GL.BindBuffer(BufferTarget.ArrayBuffer, 0);
        GL.DeleteBuffer(vertexBufferHandle);

        rayTracer?.Dispose();
    }

    protected override void OnResize(ResizeEventArgs e) {
        base.OnResize(e);

        GL.Viewport(0, 0, e.Width, e.Height);

        camera.OnResize(this.ClientSize.X, this.ClientSize.Y);
    }

    protected override void OnRenderFrame(FrameEventArgs args) {
        base.OnRenderFrame(args);

        GL.Clear(ClearBufferMask.ColorBufferBit);

        GL.UseProgram(rayTracer.Handle);
        GL.BindVertexArray(vertexArrayHandle);
        GL.BindBuffer(BufferTarget.ElementArrayBuffer, indexBufferHandle);
        GL.DrawElements(PrimitiveType.Triangles, 6, DrawElementsType.UnsignedInt, 0);

        this.SwapBuffers();
    }

    protected override void OnUpdateFrame(FrameEventArgs args) {
        base.OnUpdateFrame(args);

        var keyboardState = this.KeyboardState;
        var mouseState = this.MouseState;
        
        camera.OnUpdate((float)args.Time, mouseState, keyboardState, out CursorState cursorState);
        this.CursorState = cursorState;

        rayTracer.OnUpdate((float)args.Time, keyboardState);

        this.Title = $"FPS: {1 / args.Time:F0} ({args.Time * 1000f:F0}ms)";
    }
}
