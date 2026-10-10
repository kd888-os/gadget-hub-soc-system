using Microsoft.EntityFrameworkCore;
using GadgetCentralAPI.Models;

namespace GadgetCentralAPI.Data
{
    public class GadgetCentralDbContext : DbContext
    {
        public GadgetCentralDbContext(DbContextOptions<GadgetCentralDbContext> options) : base(options)
        {
        }

        public DbSet<InventoryItem> Inventory { get; set; }
    }
}