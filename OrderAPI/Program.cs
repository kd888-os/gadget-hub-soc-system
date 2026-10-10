using Microsoft.EntityFrameworkCore;
using OrderAPI.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddHttpClient();

// Add Database Context
builder.Services.AddDbContext<GadgetHubDbContext>(options =>
    options.UseSqlServer("Server=localhost\\SQLEXPRESS;Database=GadgetHubDB;Trusted_Connection=True;TrustServerCertificate=True;"));

var app = builder.Build();

app.MapControllers();

Console.WriteLine("[ORDER API] Order Management API starting on port 5001...");
app.Run("http://localhost:5001");