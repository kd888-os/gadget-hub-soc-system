using Microsoft.EntityFrameworkCore;
using ElectroComAPI.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Add Database Context
builder.Services.AddDbContext<ElectroComDbContext>(options =>
    options.UseSqlServer("Server=localhost\\SQLEXPRESS;Database=ElectroComDB;Trusted_Connection=True;TrustServerCertificate=True;"));

var app = builder.Build();

app.MapControllers();

Console.WriteLine("[ELECTROCOM] ElectroCom API with Inventory starting on port 5102...");
app.Run("http://localhost:5102");