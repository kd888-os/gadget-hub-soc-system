using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OrderAPI.Data;
using System.Linq;
using System.Threading.Tasks;

namespace OrderAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        private readonly GadgetHubDbContext _context;

        public ProductsController(GadgetHubDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Get all products
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAllProducts()
        {
            var products = await _context.Products
                .OrderBy(p => p.Category)
                .ThenBy(p => p.ProductName)
                .ToListAsync();

            return Ok(products);
        }

        /// <summary>
        /// Get product by ID
        /// </summary>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetProduct(int id)
        {
            var product = await _context.Products.FindAsync(id);

            if (product == null)
                return NotFound();

            return Ok(product);
        }
    }
}