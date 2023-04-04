using OpenTK.Graphics.OpenGL4;
using ImGuiNET;
using Lemon.Shaders;
using Lemon.Rendering;

internal sealed class Program {
    static void Main(string[] args) {
        using var r = new Renderer(800, 800, "Window");
        r.Run();

        Console.WriteLine("Closed.");
    }
}