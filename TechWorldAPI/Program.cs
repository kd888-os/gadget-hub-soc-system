using Microsoft.EntityFrameworkCore;
using TechWorldAPI.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Add Database Context
builder.Services.AddDbContext<TechWorldDbContext>(options =>
    options.UseSqlServer("Server=localhost\\SQLEXPRESS;Database=TechWorldDB;Trusted_Connection=True;TrustServerCertificate=True;"));

var app = builder.Build();

app.MapControllers();

Console.WriteLine("[TECHWORLD] TechWorld API with Inventory starting on port 5101...");
app.Run("http://localhost:5101");