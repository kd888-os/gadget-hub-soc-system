using Microsoft.EntityFrameworkCore;
using QuotationAPI.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddHttpClient();

// Add Database Context - UPDATED CONNECTION STRING
builder.Services.AddDbContext<QuotationDbContext>(options =>
    options.UseSqlServer("Server=localhost\\SQLEXPRESS;Database=GadgetHubDB;Trusted_Connection=True;TrustServerCertificate=True;"));

var app = builder.Build();

app.MapControllers();

Console.WriteLine("[QUOTATION API] Quotation Service starting on port 5002...");
app.Run("http://localhost:5002");