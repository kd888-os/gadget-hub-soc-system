using Microsoft.EntityFrameworkCore;
using QuotationAPI.Models;

namespace QuotationAPI.Data
{
    public class QuotationDbContext : DbContext
    {
        public QuotationDbContext(DbContextOptions<QuotationDbContext> options) : base(options)
        {
        }

        public DbSet<Quotation> Quotations { get; set; }
        public DbSet<OrderDistribution> OrderDistributions { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Quotation>()
                .HasIndex(q => q.OrderId);

            modelBuilder.Entity<OrderDistribution>()
                .HasIndex(od => od.OrderId);
        }
    }
}