using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OrderAPI.Data;
using OrderAPI.Models;
using System.Linq;
using System.Threading.Tasks;

namespace OrderAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CustomersController : ControllerBase
    {
        private readonly GadgetHubDbContext _context;

        public CustomersController(GadgetHubDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Login - Validate email and password
        /// </summary>
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var customer = await _context.Customers
                .FirstOrDefaultAsync(c => c.Email == request.Email && c.Password == request.Password);

            if (customer == null)
            {
                return Unauthorized(new { Message = "Invalid email or password" });
            }

            return Ok(new
            {
                CustomerId = customer.CustomerId,
                CustomerName = customer.CustomerName,
                Email = customer.Email
            });
        }

        /// <summary>
        /// Register new customer
        /// </summary>
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            // Check if email already exists
            var existingCustomer = await _context.Customers
                .FirstOrDefaultAsync(c => c.Email == request.Email);

            if (existingCustomer != null)
            {
                return BadRequest(new { Message = "Email already registered" });
            }

            // Create new customer
            var customer = new Customer
            {
                CustomerName = request.CustomerName,
                Email = request.Email,
                Phone = request.Phone,
                Password = request.Password,
                CreatedDate = System.DateTime.UtcNow
            };

            _context.Customers.Add(customer);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                CustomerId = customer.CustomerId,
                CustomerName = customer.CustomerName,
                Email = customer.Email,
                Message = "Registration successful!"
            });
        }

        /// <summary>
        /// Get customer by ID
        /// </summary>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetCustomer(int id)
        {
            var customer = await _context.Customers.FindAsync(id);

            if (customer == null)
                return NotFound();

            return Ok(new
            {
                CustomerId = customer.CustomerId,
                CustomerName = customer.CustomerName,
                Email = customer.Email
            });
        }
    }

    // DTOs for this controller
    public class LoginRequest
    {
        public string Email { get; set; }
        public string Password { get; set; }
    }

    public class RegisterRequest
    {
        public string CustomerName { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string Password { get; set; }
    }
}