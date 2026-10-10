using Microsoft.EntityFrameworkCore;
using OrderAPI.Models;

namespace OrderAPI.Data
{
    public class GadgetHubDbContext : DbContext
    {
        public GadgetHubDbContext(DbContextOptions<GadgetHubDbContext> options) : base(options)
        {
        }

        public DbSet<Customer> Customers { get; set; }
        public DbSet<Order> Orders { get; set; }
        public DbSet<OrderItem> OrderItems { get; set; }
        public DbSet<Product> Products { get; set; }
        public DbSet<Quotation> Quotations { get; set; }
        public DbSet<DistributorStaff> DistributorStaff { get; set; }
        public DbSet<AdminUser> AdminUsers { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Order>()
                .HasMany(o => o.Items)
                .WithOne()
                .HasForeignKey(oi => oi.OrderId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Order>()
                .HasIndex(o => o.CustomerId);

            modelBuilder.Entity<Order>()
                .HasIndex(o => o.OrderDate);

            modelBuilder.Entity<OrderItem>()
                .HasIndex(oi => oi.OrderId);
        }
    }
}