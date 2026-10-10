using Microsoft.EntityFrameworkCore;
using TechWorldAPI.Models;

namespace TechWorldAPI.Data
{
    public class TechWorldDbContext : DbContext
    {
        public TechWorldDbContext(DbContextOptions<TechWorldDbContext> options) : base(options)
        {
        }

        public DbSet<InventoryItem> Inventory { get; set; }
    }
}