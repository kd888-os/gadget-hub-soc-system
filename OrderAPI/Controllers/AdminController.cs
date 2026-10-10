using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OrderAPI.Data;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace OrderAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AdminController : ControllerBase
    {
        private readonly GadgetHubDbContext _context;

        public AdminController(GadgetHubDbContext context)
        {
            _context = context;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] AdminLoginRequest request)
        {
            var admin = await _context.AdminUsers
                .FirstOrDefaultAsync(a =>
                    a.Username == request.Username &&
                    a.Password == request.Password);

            if (admin == null)
                return Unauthorized(new { Message = "Invalid username or password" });

            Console.WriteLine($"[ORDER API] Admin login: {admin.FullName}");

            return Ok(new
            {
                AdminId = admin.AdminId,
                FullName = admin.FullName,
                Email = admin.Email
            });
        }

        [HttpGet("orders")]
        public async Task<IActionResult> GetAllOrders()
        {
            Console.WriteLine("[ORDER API] Admin fetching all orders...");

            var orders = await _context.Orders
                .Include(o => o.Items)
                .OrderByDescending(o => o.OrderDate)
                .ToListAsync();

            // Fix nulls
            foreach (var o in orders)
            {
                o.Status ??= "Confirmed";
                o.SelectedDistributor ??= "Pending";
            }

            Console.WriteLine($"[ORDER API] Returning {orders.Count} orders");
            return Ok(orders);
        }

        [HttpGet("quotations")]
        public async Task<IActionResult> GetAllQuotations()
        {
            Console.WriteLine("[ORDER API] Admin fetching all quotations...");

            var quotations = await _context.Quotations
                .OrderByDescending(q => q.QuotationDate)
                .Take(100)
                .ToListAsync();

            // Fix nulls
            foreach (var q in quotations)
            {
                q.Status ??= "Confirmed";
                q.DistributorOrderId ??= "";
                q.ConfirmedBy ??= "";
            }

            Console.WriteLine($"[ORDER API] Returning {quotations.Count} quotations");
            return Ok(quotations);
        }

        [HttpGet("statistics")]
        public async Task<IActionResult> GetStatistics()
        {
            Console.WriteLine("[ORDER API] Admin fetching statistics...");

            var totalOrders = await _context.Orders.CountAsync();
            var totalRevenue = await _context.Orders.SumAsync(o => (decimal?)o.TotalAmount) ?? 0;
            var totalCustomers = await _context.Customers.CountAsync();
            var totalProducts = await _context.Products.CountAsync();

            var today = DateTime.Today;
            var ordersToday = await _context.Orders
                .Where(o => o.OrderDate.Date == today)
                .CountAsync();

            var revenueToday = await _context.Orders
                .Where(o => o.OrderDate.Date == today)
                .SumAsync(o => (decimal?)o.TotalAmount) ?? 0;

            return Ok(new
            {
                TotalOrders = totalOrders,
                TotalRevenue = totalRevenue,
                TotalCustomers = totalCustomers,
                TotalProducts = totalProducts,
                OrdersToday = ordersToday,
                RevenueToday = revenueToday
            });
        }
    }

    public class AdminLoginRequest
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }
}