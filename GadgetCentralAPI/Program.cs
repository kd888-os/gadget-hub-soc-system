using Microsoft.EntityFrameworkCore;
using GadgetCentralAPI.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Add Database Context
builder.Services.AddDbContext<GadgetCentralDbContext>(options =>
    options.UseSqlServer("Server=localhost\\SQLEXPRESS;Database=GadgetCentralDB;Trusted_Connection=True;TrustServerCertificate=True;"));

var app = builder.Build();

app.MapControllers();

Console.WriteLine("[GADGET CENTRAL] Gadget Central API with Inventory starting on port 5103...");
app.Run("http://localhost:5103");