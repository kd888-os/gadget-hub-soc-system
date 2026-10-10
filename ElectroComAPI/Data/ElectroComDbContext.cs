using Microsoft.EntityFrameworkCore;
using ElectroComAPI.Models;

namespace ElectroComAPI.Data
{
    public class ElectroComDbContext : DbContext
    {
        public ElectroComDbContext(DbContextOptions<ElectroComDbContext> options) : base(options)
        {
        }

        public DbSet<InventoryItem> Inventory { get; set; }
    }
}